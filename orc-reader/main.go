package main

import (
	"fmt"

	"github.com/scritchley/orc"
)

func main() {
	orc_file, err := orc.Open("../orc-writer/example.orc")
	if err != nil {
		panic(err)
	}
	fmt.Println(orc_file.Metadata())
}
