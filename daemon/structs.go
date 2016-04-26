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
	Title   string `json:"title",omitempty`
	Enabled bool   `json:"enabled",omitempty`
}

type DexSite struct {
	url, dexPath, dexEnabledFile string
	config                       map[string]map[string]DexModule
	moduleMap                    map[string]struct{}
	enabledFiles                 map[string][]string
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

	var enabledConfig map[string][]string
	err = yaml.Unmarshal(enabledSrc, &enabledConfig)
	if err != nil {
		panic(err)
	}

	var enabledModules []string
	site.moduleMap = make(map[string]struct{})
	site.enabledFiles = make(map[string][]string)

	if siteEnabled, hasSiteEnabled := enabledConfig[site.url]; hasSiteEnabled {
		enabledModules = append(enabledModules, siteEnabled...)
		log.Println("Enabled modules for "+site.url+":", siteEnabled)
	} else {
		log.Println("No enabled modules for " + site.url)
	}

	if globalEnabled, hasGlobalEnabled := enabledConfig["global"]; hasGlobalEnabled {
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
	site.getModules(site.url)
}

func (site *DexSite) getModules(moduleGroup string) {
	log.Println("Modules in " + moduleGroup + ":")

	walkFn := func(path string, info os.FileInfo, err error) error {
		relPath, _ := filepath.Rel(site.dexPath, path)
		pathBits := strings.Split(relPath, "/")

		// skip da root
		if len(pathBits) == 1 {
			return nil
		}

		moduleKey := fmt.Sprintf("%s/%s", pathBits[0], pathBits[1])

		if info.IsDir() {
			if len(pathBits) == 2 {
				// Set config if this is a module directory
				if _, exists := site.config[pathBits[0]]; !exists {
					site.config[pathBits[0]] = make(map[string]DexModule)
				}

				_, enabled := site.moduleMap[moduleKey]

				site.config[pathBits[0]][moduleKey] = DexModule{
					Title:   pathBits[1],
					Enabled: enabled,
				}
			}
		} else {
			// Save files by file type
			ext := filepath.Ext(path)
			if ext == "" {
				return nil
			}
			ext = ext[1:] // trim the initial dot

			if len(pathBits) == 2 {
				site.enabledFiles[ext] = append(site.enabledFiles[ext], path)
			} else if len(pathBits) > 2 {
				if _, enabled := site.moduleMap[moduleKey]; enabled {
					site.enabledFiles[ext] = append(site.enabledFiles[ext], path)
				}
			}
		}

		return nil
	}

	if moduleGroup == "global" {
		if err := filepath.Walk(filepath.Join(site.dexPath, "global"), walkFn); err != nil {
			log.Fatal(err)
		}
	} else {
		if err := filepath.Walk(filepath.Join(site.dexPath, "utilities"), walkFn); err != nil {
			log.Fatal(err)
		}

		if err := filepath.Walk(filepath.Join(site.dexPath, site.url), walkFn); err != nil {
			log.Fatal(err)
		}
	}

	jsonString, _ := json.MarshalIndent(site.enabledFiles, "", "  ")
	log.Println("site.enabledFiles:", string(jsonString))
}

func (site *DexSite) getJSON() []byte {
	jsonString, err := json.MarshalIndent(site.config, "", "  ")

	if err != nil {
		log.Println("jsonString:", string(jsonString))
		return nil
	}

	return jsonString
}

func (site *DexSite) getFile(ext string) []byte {
	if _, exists := site.enabledFiles[ext]; !exists {
		return nil
	}

	var lilBits []string
	if site.url == "global" {
		lilBits = []string{"/* Global " + strings.ToUpper(ext) + " files */"}
	} else {
		lilBits = []string{"/* " + strings.ToUpper(ext) + " files for " + site.url + " */\n"}
	}

	for idx, filePath := range site.enabledFiles[ext] {
		relPath, _ := filepath.Rel(site.dexPath, filePath)
		if fileContents, exists := ioutil.ReadFile(filePath); exists == nil {
			if idx > 0 {
				lilBits = append(lilBits, "\n\n")
			}
			lilBits = append(lilBits, "/* @begin "+relPath+" */")
			lilBits = append(lilBits, string(fileContents))
			lilBits = append(lilBits, "/* @end "+relPath+" */")
		}
	}

	return []byte(strings.Join(lilBits, "\n\n"))
}
