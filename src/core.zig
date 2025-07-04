/// A collection of models which are formed with information from WikiPedia website, which is the free encyclopedia that anyone can edit.
pub const Data = struct {
    /// A data could be treated as a collection of datum
    collection: []const Datum,
    /// a meaning of data, such as quantity, quality, fact, statistics, or other basic units of meaning
    meaning: []const u8,
    /// there are two types of data
    category: union {
        /// A collection of value to convey information
        collection: "collection",
        /// A simply sequences of symbols that could be further interpreted formally.
        sequence_of_symbols: "sequence_of_symbols",
    },
    collected_by_method: union {
        /// Measurement is the quantification of attributes of an object or event, which can be used to compare with other objects or events.
        measurement: "measurement",
        /// in the natural sciences, observation is an act or insance of noticing or perceving and the acquisition of information from a primary source.
        observation: "observation",
        /// Query, a precise request for informatin retrieval made to a database, data structure or information system.
        /// In computing and information science, it is the task of identifiying and retrieving information system resources that are relevant to an information need.
        query: "query",
        /// Analysis is the process of breaking a complex topic or substance into smaller parts in order to gain a better understanding of it.
        analysis: "analysis",
        /// Knowledge representation (KR) aims to model informatin in a structured manner to formally represent it as knowledge in knowledge-based systems whereas knowledge representation and reasoning also aims to understand, reason, and interpret knowledge.
        represented: "represented",
    },
    /// store data as a file for safe access, the data are in the storage medium.
    representation: union {
        /// A file handler for implementation
        file: @import("std").fs.file,
        /// A URL to access
        web: []const u8,
        /// A message on IM
        im_message: []const u8,
        /// An ammail received by an email client
        email: []const u8,
    },
    /// formally organize data
    organized_into: enum { structure, unstructure, semi_structure },
};

/// Datum comprises a value and a category
pub const Datum = struct {
    /// a category for the values.
    category: union { discrete: "discrete", continuous: "continuous", mixed: "mixed" },
    /// every datum should hold a value for human's or computer's reading
    value: []const u8,
};

pub const Dataset = struct {
    description: []const u8 = "a collection of data, table or document or file",
    /// data set is the collection of data
    collection: []const Data,
    /// A Dataset would correspond with some actual digital object
    correspond_with: union {
        database_tables: []const u8,
        documents: []const u8,
        files: []const u8,
    },
};

pub const Database = struct {
    description: []const u8 = "an organized collection of data based on a DBMS, mainly used for capturing data.",
    /// whether organized or not
    organized: bool,
    /// to capture and analyze the data
    interact_with: enum {
        /// through a user interface, such as web browser, desktop application, mobile application.
        end_user,
        /// with an application interface through a network transfer on a distributed system
        /// or inter-process communication on a local operating system
        application,
        /// with database itself
        itself,
    },
};

pub const BigData = struct {
    /// Big data primarily refers to data sets that are too large or complex to be dealt with by traditional data-processing software.
    description: []const u8,
    /// Many challenges if you want to analyze big data
    challenges_of_big_data_analysis: enum {
        /// first of all, to collect the data
        capturing,
        /// store the data for continuous analysis and retrieve
        storage,
        /// to extract the value from the data, value is one of the "five Vs"
        analysis,
        /// how to search the data in a big data system may be a general challenge for every one in whole life
        /// equals "What you do"
        search,
        /// to share the data with other people for amplifying the value of data.
        sharing,
        /// transfer the data between different systems, a way to make data together or just divide data into different parts
        transfer,
        /// to visualize the data in a way that is easy to understand
        visualization,
        /// information retrieval for information need with a specific structured request.
        /// equals "How you ask"
        querying,
        /// timeliness of the data
        updating,
        /// the ability of an big data system to seclude the information
        information_privacy,
        /// the data come from, differs to the term 'datasource'.
        data_source,
    },
    /// Current the term big data tends to refer to the use of followings
    trending_usage: enum {
        predicative_analytics,
        user_behavior_analytics,
        other_advanced_analytics,
    },
    /// As time goes by, the size and number of available data sets have grown rapidly as data is collected by devices.
    growable: bool,
    /// The data is collected by the following devices.
    collected_by_devices: enum {
        mobile,
        iot,
        aerial_equipment,
        software_log,
        camera,
        microphone,
        rfid_reader,
        wireless_sensor_network,
        other,
    },
};

pub const DataStorage = struct {
    description: []const u8 = "Data storage is the recording (storing) of information (data) in a storage medium.",
    medium_type: enum {
        /// A digital, machine-readable storage medium
        digital_and_machine_readable,
        /// A non-digital storage medium
        non_digital,
    },
    /// A category of storage medium
    non_digital_storage_media: enum {
        /// by hand
        handwriting_or_print,
        phonographic_recording_or_film,
        magnetic_tape_or_magnetic,
        optical_discs_or_optical,
        /// Ribonucleic acid
        rna,
        /// Deoxyribonucleic acid
        dna,
    },
};
