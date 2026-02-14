package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/scritchley/orc"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: orc-writer [basic|advanced]")
		os.Exit(1)
	}

	command := os.Args[1]

	switch command {
	case "basic":
		createBasicORC()
	case "advanced":
		createAdvancedORC()
	default:
		fmt.Println("Unknown command. Use 'basic' or 'advanced'.")
		os.Exit(1)
	}
}

func createBasicORC() {
	// Define the schema for our ORC file
	schema, err := orc.ParseSchema("struct<name:string,age:int,email:string>")
	if err != nil {
		log.Fatal(err)
	}

	// Create a new ORC file
	file, err := os.Create("example.orc")
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	// Create a writer with the schema
	writer, err := orc.NewWriter(file, orc.SetSchema(schema))
	if err != nil {
		log.Fatal(err)
	}
	defer writer.Close()

	// Write data - values must be passed in the order defined in the schema
	err = writer.Write("Alice", 30, "alice@example.com")
	if err != nil {
		log.Fatal(err)
	}

	err = writer.Write("Bob", 25, "bob@example.com")
	if err != nil {
		log.Fatal(err)
	}

	err = writer.Write("Charlie", 35, "charlie@example.com")
	if err != nil {
		log.Fatal(err)
	}

	log.Println("Basic ORC file 'example.orc' created successfully!")
}

func createAdvancedORC() {
	// Define a more complex schema with various data types
	schema, err := orc.ParseSchema("struct<id:int,name:string,age:int,salary:double,is_active:boolean,created_at:string>")
	if err != nil {
		log.Fatal(err)
	}

	// Create a new ORC file with compression
	file, err := os.Create("advanced_example.orc")
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	// Create a writer with the schema
	writer, err := orc.NewWriter(file, orc.SetSchema(schema))
	if err != nil {
		log.Fatal(err)
	}
	defer writer.Close()

	// Write sample data with various types
	sampleData := [][]interface{}{
		{1, "Alice", 30, 75000.50, true, time.Now().Format("2006-01-02")},
		{2, "Bob", 25, 65000.75, true, time.Now().Format("2006-01-02")},
		{3, "Charlie", 35, 85000.00, false, time.Now().Format("2006-01-02")},
		{4, "Diana", 28, 70000.25, true, time.Now().Format("2006-01-02")},
	}

	// Write each row to the ORC file
	for _, row := range sampleData {
		err := writer.Write(row...)
		if err != nil {
			log.Fatal(err)
		}
	}

	log.Println("Advanced ORC file 'advanced_example.orc' created successfully!")
}
