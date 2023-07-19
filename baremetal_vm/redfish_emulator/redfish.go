package main

import (
	"flag"
	"fmt"
	"log"
    "os"
	"net/http"
	"net/http/httputil"
	"encoding/json"

	"github.com/gorilla/mux"
	"github.com/gorilla/handlers"
)

type resetType struct {
	ResetType string
}

func handleReset(w http.ResponseWriter, r *http.Request) {
	log.Println("-- Reset System " + mux.Vars(r)["identity"])

	var rt resetType
	err := json.NewDecoder(r.Body).Decode(&rt)
	if err != nil {
		http.Error(w, "Unable to decode json body", http.StatusBadRequest)
	}

	identity := mux.Vars(r)["identity"]
	if rt.ResetType == "ForceOn" {
		log.Println("ForceOn: " + identity)
	} else if rt.ResetType == "ForceOff" {
		log.Println("ForceOff: " + identity)
	} else {
		http.Error(w, "Invalid ResetType", http.StatusBadRequest)
	}
}

func handleCatchAll(w http.ResponseWriter, r *http.Request) {
	requestDump, err := httputil.DumpRequest(r, true)
	if err != nil {
		fmt.Println(err)
	}
	log.Println("Catch All / --- ", string(requestDump))
}

func main() {
	var port string

	flag.StringVar(&port, "port", "9000", "port to listen on")
	flag.Parse()

	router := mux.NewRouter()

	router.HandleFunc("/", handleCatchAll)
//	router.HandleFunc("/redfish/v1/Managers/{identity}/VirtualMedia/{device}/Actions/VirtualMedia.InsertMedia", handleInsertMedia).Methods("POST")
//	router.HandleFunc("/redfish/v1/Managers/{identity}/VirtualMedia/{device}/Actions/VirtualMedia.EjectMedia", handleEjectMedia).Methods("POST")
	router.HandleFunc("/redfish/v1/Systems/{identity}/Actions/ComputerSystem.Reset", handleReset).Methods("POST")

	log.Println("Starting RedFish mock server on port ", port)
	loggedRouter := handlers.LoggingHandler(os.Stdout, router)
	log.Fatal(http.ListenAndServe(":"+port, loggedRouter))
}
