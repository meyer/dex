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
	"strings"
)

type DexModule struct {
	Title    string `json:"title",omitempty`
	Category string `json:"category",omitempty`
	Enabled  bool   `json:"enabled",omitempty`
}

type DexSite struct {
	url            string
	dexPath        string
	dexEnabledFile string
	enabledModules []string
	siteModules    map[string]map[string][]string
	utilModules    map[string]map[string][]string
	globalModules  map[string]map[string][]string
	config         map[string]map[string]DexModule
	moduleMap      map[string]struct{}
}

func (site *DexSite) loadConfig() {
	usr, _ := user.Current()
	site.dexPath, _ = filepath.EvalSymlinks(filepath.Join(usr.HomeDir, ".dex"))
	dexEnabledFile := filepath.Join(site.dexPath, "enabled.yaml")

	// TODO: check to see if dexPath exists

	// Read dexPath/enabled.yaml
	enabledSrc, err := ioutil.ReadFile(dexEnabledFile)
	if err != nil {
		panic(err)
	}

	var enabled map[string][]string
	err = yaml.Unmarshal(enabledSrc, &enabled)
	if err != nil {
		panic(err)
	}

	var enabledModules []string
	site.moduleMap = make(map[string]struct{})

	if siteEnabled, hasSiteEnabled := enabled[site.url]; hasSiteEnabled {
		enabledModules = append(enabledModules, siteEnabled...)
		log.Println("Enabled modules for "+site.url+":", siteEnabled)
	} else {
		log.Println("No enabled modules for " + site.url)
	}

	if globalEnabled, hasGlobalEnabled := enabled["global"]; hasGlobalEnabled {
		enabledModules = append(enabledModules, globalEnabled...)
		log.Println("Enabled global modules:", globalEnabled)
	} else {
		log.Println("No enabled global modules")
	}

	// this is gross
	for _, k := range enabledModules {
		site.moduleMap[k] = struct{}{}
	}

	site.config = make(map[string]map[string]DexModule)
	site.utilModules = site.getModules("utilities")
	site.siteModules = site.getModules(site.url)
	site.globalModules = site.getModules("global")

	site.getJSON()

	// log.Println(siteEnabled)hasGlobalEnabled
}

func (site *DexSite) getModules(moduleGroup string) map[string]map[string][]string {
	rootPath := filepath.Join(site.dexPath, moduleGroup)

	modules := make(map[string]map[string][]string)

	log.Println("Modules in " + moduleGroup + ":")

	walkFn := func(path string, info os.FileInfo, err error) error {
		if path == rootPath {
			return nil
		}

		relPath, _ := filepath.Rel(site.dexPath, path)
		pathBits := strings.Split(relPath, "/")
		moduleKey := fmt.Sprintf("%s/%s", pathBits[0], pathBits[1])

		category := "global"
		if pathBits[0] != "global" {
			category = site.url
		}

		// Set config if this is a module directory
		if len(pathBits) == 2 && info.IsDir() {
			if _, exists := site.config[category]; !exists {
				site.config[category] = map[string]DexModule{}
			}

			_, enabled := site.moduleMap[moduleKey]

			site.config[category][moduleKey] = DexModule{
				pathBits[0],
				pathBits[1],
				enabled,
			}
		}

		// Save files by file type
		ext := filepath.Ext(path)
		if ext != "" && !info.IsDir() {
			ext = ext[1:]
			log.Println("modules -> " + moduleKey + " -> " + ext)

			if _, exists := modules[moduleKey]; !exists {
				modules[moduleKey] = make(map[string][]string)
			}

			modules[moduleKey][ext] = append(modules[moduleKey][ext], path)
			log.Println(modules[moduleKey][ext])
			log.Println("=======")
		}

		return nil
	}

	err := filepath.Walk(rootPath, walkFn)
	if err != nil {
		log.Fatal(err)
	}
	return modules
}

func (site *DexSite) getJSON() []byte {
	jsonString, err := json.MarshalIndent(site.config, "", "  ")

	if err != nil {
		return nil
	}

	log.Println("jsonString:", string(jsonString))

	return jsonString
}
