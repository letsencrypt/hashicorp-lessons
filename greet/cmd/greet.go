package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"

	"gopkg.in/yaml.v3"
)

// config represents to contents of our YAML configuration file. It's fields are
// exported for this purpose.
type config struct {
	Name string
	Port int
}

func main() {
	// Declare and parse our CLI flags.
	configFile := flag.String("c", "", "Path to the YAML config file")
	flag.Parse()

	// Ensure that the '-c' flag was passed.
	if *configFile == "" {
		log.Fatal("Flag '-c' is required, use '-help' for more info")
	}

	// Load the contents of the config file into memory.
	configData, err := os.ReadFile(*configFile)
	if err != nil {
		log.Fatalf("While loading the config file at %q: %s", *configFile, err)
	}

	// Unmarshal our config file.
	var conf config
	err = yaml.Unmarshal(configData, &conf)
	if err != nil {
		log.Fatalf("While unmarshaling the config file at %q: %s", *configFile, err)
	}

	// Declare our request handler.
	http.HandleFunc(
		"/",
		func(w http.ResponseWriter, r *http.Request) {
			fmt.Fprintf(w, "Hello, %s", conf.Name)
		},
	)

	// Start our web server. If an error is encountered it will log and exit
	// immediately.
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", conf.Port), nil))
}
