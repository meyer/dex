package main

import (
	"encoding/json"
	"fmt"
	"github.com/golang/glog"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"os"
	"os/user"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type DexSite struct {
	DexPath, DexEnabledFile string
	config                  map[string]map[string]bool
	moduleMap               map[string]struct{}
	enabledFiles            map[string]map[string][]string
	yamlConfig              map[string][]string
}

func (site *DexSite) init() {
	usr, _ := user.Current()
	site.DexPath, _ = filepath.EvalSymlinks(filepath.Join(usr.HomeDir, ".dex"))
	site.DexEnabledFile = filepath.Join(site.DexPath, "enabled.yaml")

	enabledSrc, err := ioutil.ReadFile(site.DexEnabledFile)
	if err != nil {
		// TODO: catch funky Windows error here
		glog.Error("site.DexPath:", site.DexPath)
		glog.Error("Error reading site.DexEnabledFile:", site.DexEnabledFile)
		panic(err)
	}

	// Load enabled modules from config
	if err := yaml.Unmarshal(enabledSrc, &site.yamlConfig); err != nil {
		panic(err)
	}
}

func (site *DexSite) getConfig() map[string]map[string][]string {
	config := make(map[string]map[string][]string)

	ignoredDirs := map[string]bool{
		"node_modules": true,
	}

	config["available"] = make(map[string][]string)
	config["enabled"] = site.yamlConfig

	if siteDirs, err := ioutil.ReadDir(site.DexPath); err == nil {
		for _, siteDir := range siteDirs {
			if ignoredDirs[siteDir.Name()] || !siteDir.IsDir() || string(siteDir.Name()[0]) == "." {
				continue
			}

			glog.V(2).Info("Reading modules from DexPath/" + siteDir.Name() + "...")

			// Update config object with available modules
			dirPath := filepath.Join(site.DexPath, siteDir.Name())

			if files, err := ioutil.ReadDir(dirPath); err == nil {
				for _, file := range files {
					glog.V(3).Info(" - module:", file)
					if file.IsDir() {
						moduleKey := siteDir.Name() + "/" + file.Name()
						// Add to config, default to false
						config["available"][siteDir.Name()] = append(config["available"][siteDir.Name()], moduleKey)
					}
				}
			}
		}

	}

	return config
}

func getFilesAtPath(dirPath string, ext string) []string {
	fileArray := []string{}
	files, err := ioutil.ReadDir(dirPath)
	if err != nil {
		// glog.V(1).Error("Error!", err)
		return fileArray
	}

	if len(files) == 0 {
		glog.V(2).Info("No " + ext + " files in " + dirPath)
		return fileArray
	}

	for _, file := range files {
		if !file.IsDir() {
			filePath := filepath.Join(dirPath, file.Name())
			fileExt := filepath.Ext(filePath)

			if fileExt == "" || fileExt[1:] != ext {
				continue
			}

			glog.V(3).Info(" - " + filePath)

			fileSrc, err := ioutil.ReadFile(filePath)
			if err != nil {
				glog.Fatal(err)
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

func (site *DexSite) getFileForHostname(ext string, hostname string) []byte {
	// Add root-level site files
	fileSlice := getFilesAtPath(filepath.Join(site.DexPath, hostname), ext)

	// Update config object with enabled modules
	if enabledModules, hasEnabled := site.yamlConfig[hostname]; hasEnabled {
		glog.V(2).Info("Enabled modules for " + hostname + ":")
		for _, k := range enabledModules {
			glog.V(2).Info(" - module:", k)
			dirPath := filepath.Join(site.DexPath, k)

			fileSlice = append(fileSlice, getFilesAtPath(dirPath, ext)...)
		}
	} else {
		glog.V(2).Info("No enabled modules for " + hostname + ".")
	}

	if len(fileSlice) == 0 {
		return nil
	}

	return []byte(strings.Join(fileSlice, "\n\n"))
}

func stringifyOrDie(o interface{}) []byte {
	jsonString, err := json.MarshalIndent(o, "", "  ")

	if err != nil {
		glog.Fatal(err)
		return nil
	}

	return jsonString
}

func (site *DexSite) getConfigAsJSON() []byte {
	return stringifyOrDie(site.getConfig())
}

func (site *DexSite) toggleModuleForHostname(toggledModule string, hostname string) []byte {
	if _, err := os.Stat(filepath.Join(site.DexPath, toggledModule)); err != nil {
		glog.Fatal("Invalid module :(")
		return stringifyOrDie(site.yamlConfig)
	}

	newSlice := site.yamlConfig[hostname]
	moduleWasDisabled := false

	if enabledModules, hasEnabled := site.yamlConfig[hostname]; hasEnabled {
		for i, module := range enabledModules {
			if module == toggledModule {
				glog.V(1).Info("Disabled " + toggledModule + " for " + hostname)
				moduleWasDisabled = true
				newSlice = append(newSlice[:i], newSlice[i+1:]...)
				break
			}
		}
	}

	if !moduleWasDisabled {
		glog.V(1).Info("Enabled " + toggledModule + " for " + hostname)
		newSlice = append(newSlice, toggledModule)
		sort.Strings(newSlice)
	}

	if len(newSlice) > 0 {
		site.yamlConfig[hostname] = newSlice
	} else {
		delete(site.yamlConfig, hostname)
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

	return stringifyOrDie(site.yamlConfig)
}
