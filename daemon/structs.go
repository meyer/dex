package main

import (
	"encoding/json"
	"fmt"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"log"
	"os"
	"os/user"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type DexSite struct {
	url, DexPath, DexEnabledFile string
	config                       map[string]map[string]bool
	moduleMap                    map[string]struct{}
	enabledFiles                 map[string]map[string][]string
	yamlConfig                   map[string][]string
}

func (site *DexSite) init() {
	usr, _ := user.Current()
	site.DexPath, _ = filepath.EvalSymlinks(filepath.Join(usr.HomeDir, ".dex"))
	site.DexEnabledFile = filepath.Join(site.DexPath, "enabled.yaml")

	enabledSrc, err := ioutil.ReadFile(site.DexEnabledFile)
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
		dirPath := filepath.Join(site.DexPath, c)
		var configKey string
		if c == "global" {
			configKey = c
		} else {
			configKey = site.url
		}

		// log.Println("Reading modules from DexPath/" + c + "...")
		if files, err := ioutil.ReadDir(dirPath); err == nil {
			for _, file := range files {
				moduleKey := c + "/" + file.Name()
				// log.Println(" - module:", moduleKey)
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
		// log.Println("Updating enabled modules...")

		if enabledModules, hasEnabled := site.yamlConfig[configKey]; hasEnabled {
			for _, moduleKey := range enabledModules {
				// log.Println(" - module:", moduleKey)
				bits := strings.Split(moduleKey, "/")

				// Ignore invalid module names
				if len(bits) != 2 {
					continue
				}

				// Make sure module exists
				if _, err := os.Stat(filepath.Join(site.DexPath, moduleKey)); err == nil {
					if _, exists := config[configKey]; !exists {
						config[configKey] = make(map[string]bool)
					}
					config[configKey][moduleKey] = true
				}
			}
		} else {
			// log.Println("No enabled modules for " + site.url + ".")
		}
	}

	return config
}

func getFilesAtPath(dirPath string, ext string) []string {
	fileArray := []string{}
	files, err := ioutil.ReadDir(dirPath)
	if err != nil {
		// log.Println("Error!", err)
		return fileArray
	}

	if len(files) == 0 {
		// log.Println("No " + ext + " files in " + dirPath)
		return fileArray
	}

	for _, file := range files {
		if !file.IsDir() {
			filePath := filepath.Join(dirPath, file.Name())
			fileExt := filepath.Ext(filePath)

			if fileExt == "" || fileExt[1:] != ext {
				continue
			}

			// log.Println(" - " + filePath)

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
	fileSlice := getFilesAtPath(filepath.Join(site.DexPath, site.url), ext)

	// Update config object with enabled modules
	if enabledModules, hasEnabled := site.yamlConfig[site.url]; hasEnabled {
		// log.Println("Enabled modules for " + site.url + ":")
		for _, k := range enabledModules {
			// log.Println(" - module:", k)
			dirPath := filepath.Join(site.DexPath, k)

			fileSlice = append(fileSlice, getFilesAtPath(dirPath, ext)...)
		}
	} else {
		// log.Println("No enabled modules for " + site.url + ".")
	}

	if len(fileSlice) == 0 {
		return nil
	}

	return []byte(strings.Join(fileSlice, "\n\n"))
}

func stringifyOrDie(o interface{}) []byte {
	jsonString, err := json.MarshalIndent(o, "", "  ")

	if err != nil {
		log.Fatal(err)
		return nil
	}

	return jsonString
}

func (site *DexSite) getConfigAsJSON() []byte {
	return stringifyOrDie(site.getConfig())
}

func (site *DexSite) toggleModule(toggledModule string) []byte {
	payload := map[string]interface{}{
		"module":  toggledModule,
		"status":  "error",
		"message": "Some kind of error occurred :(",
	}

	if _, err := os.Stat(filepath.Join(site.DexPath, toggledModule)); err != nil {
		payload["message"] = "Invalid module :("
		return stringifyOrDie(payload)
	}

	newSlice := site.yamlConfig[site.url]

	if enabledModules, hasEnabled := site.yamlConfig[site.url]; hasEnabled {
		for i, module := range enabledModules {
			if module == toggledModule {
				// log.Println("Disabled " + toggledModule + " for " + site.url)
				payload["action"] = "disabled"
				payload["status"] = "success"
				payload["message"] = "Disabled " + toggledModule + " for " + site.url
				newSlice = append(newSlice[:i], newSlice[i+1:]...)
				break
			}
		}
	}

	if _, e := payload["action"]; !e {
		// log.Println("Enabled " + toggledModule + " for " + site.url)
		payload["action"] = "enabled"
		payload["status"] = "success"
		payload["message"] = "Enabled " + toggledModule + " for " + site.url
		newSlice = append(newSlice, toggledModule)
		sort.Strings(newSlice)
	}

	if len(newSlice) > 0 {
		site.yamlConfig[site.url] = newSlice
	} else {
		delete(site.yamlConfig, site.url)
	}

	d, _ := yaml.Marshal(site.yamlConfig)

	f, err := os.Create(site.DexEnabledFile)
	if err != nil {
		panic(err)
	}

	defer f.Close()

	// Write header
	f.WriteString(fmt.Sprintf(
		"# Generated by dexd %s\n# %s\n---\n",
		dexVersion,
		time.Now().Format(time.UnixDate),
	))

	// Write YAML
	_, err = f.Write(d)
	if err != nil {
		panic(err)
	}

	// Sync changes to disk
	f.Sync()

	return stringifyOrDie(payload)
}
