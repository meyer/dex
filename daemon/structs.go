package main

import (
	"encoding/json"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"log"
	"os"
	"os/user"
	"path/filepath"
	"strings"
)

type DexSite struct {
	url, dexPath string
	config       map[string]map[string]bool
	moduleMap    map[string]struct{}
	enabledFiles map[string]map[string][]string
	yamlConfig   map[string][]string
}

func (site *DexSite) init() {
	usr, _ := user.Current()
	site.dexPath, _ = filepath.EvalSymlinks(filepath.Join(usr.HomeDir, ".dex"))
	dexEnabledFile := filepath.Join(site.dexPath, "enabled.yaml")

	enabledSrc, err := ioutil.ReadFile(dexEnabledFile)
	if err != nil {
		panic(err)
	}

	// Load enabled modules from config
	if err := yaml.Unmarshal(enabledSrc, &site.yamlConfig); err != nil {
		panic(err)
	}
}

func (site *DexSite) getConfig() map[string]map[string]bool {
	config := make(map[string]map[string]bool)

	for _, c := range [3]string{site.url, "utilities", "global"} {
		// Update config object with available modules
		dirPath := filepath.Join(site.dexPath, c)
		var configKey string
		if c == "global" {
			configKey = c
		} else {
			configKey = site.url
		}

		log.Println("Reading modules from dexPath/" + c + "...")
		if files, err := ioutil.ReadDir(dirPath); err == nil {
			for _, file := range files {
				moduleKey := c + "/" + file.Name()
				log.Println(" - module:", moduleKey)
				if file.IsDir() {
					if _, exists := config[configKey]; !exists {
						config[configKey] = make(map[string]bool)
					}
					// Add to config, default to false
					config[configKey][moduleKey] = false
				}
			}
		}

		// Update config object with enabled modules
		log.Println("Updating enabled modules...")

		if enabledModules, hasEnabled := site.yamlConfig[configKey]; hasEnabled {
			for _, moduleKey := range enabledModules {
				log.Println(" - module:", moduleKey)
				bits := strings.Split(moduleKey, "/")

				// Ignore invalid module names
				if len(bits) != 2 {
					continue
				}

				// Make sure module exists
				if _, err := os.Stat(filepath.Join(site.dexPath, moduleKey)); err == nil {
					if _, exists := config[configKey]; !exists {
						config[configKey] = make(map[string]bool)
					}
					config[configKey][moduleKey] = true
				}
			}
		} else {
			log.Println("No enabled modules for " + site.url + ".")
		}
	}

	return config
}

func getFilesAtPath(dirPath string, ext string) []string {
	fileArray := []string{}
	files, err := ioutil.ReadDir(dirPath)
	if err != nil {
		log.Println("Error!", err)
		return fileArray
	}

	if len(files) == 0 {
		log.Println("No " + ext + " files in " + dirPath)
		return fileArray
	}

	for _, file := range files {
		if !file.IsDir() {
			filePath := filepath.Join(dirPath, file.Name())
			fileExt := filepath.Ext(filePath)

			if fileExt == "" || fileExt[1:] != ext {
				continue
			}

			log.Println(" - " + filePath)

			fileSrc, err := ioutil.ReadFile(filePath)
			if err != nil {
				log.Fatal(err)
				continue
			}

			filePrefix := "/* @begin " + filePath + " */"
			fileSuffix := "/* @end " + filePath + " */"

			if ext == "js" {
				filePrefix = filePrefix + "\n(function(){"
				fileSuffix = "})();\n" + fileSuffix
			}

			fileArray = append(
				fileArray,
				filePrefix,
				string(fileSrc),
				fileSuffix,
			)
		}
	}

	return fileArray
}

func (site *DexSite) getFile(ext string) []byte {
	// Add root-level site files
	fileSlice := getFilesAtPath(filepath.Join(site.dexPath, site.url), ext)

	// Update config object with enabled modules
	if enabledModules, hasEnabled := site.yamlConfig[site.url]; hasEnabled {
		log.Println("Enabled modules for " + site.url + ":")
		for _, k := range enabledModules {
			log.Println(" - module:", k)
			dirPath := filepath.Join(site.dexPath, k)

			fileSlice = append(fileSlice, getFilesAtPath(dirPath, ext)...)
		}
	} else {
		log.Println("No enabled modules for " + site.url + ".")
	}

	if len(fileSlice) == 0 {
		return nil
	}

	return []byte(strings.Join(fileSlice, "\n\n"))
}

func (site *DexSite) getJSON() []byte {
	config := site.getConfig()
	jsonString, err := json.MarshalIndent(config, "", "  ")

	if err != nil {
		log.Fatal(err)
		return nil
	}

	return jsonString
}
