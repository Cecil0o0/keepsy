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
    collected_by: union {
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
};

/// Datum comprises a value and a category
pub const Datum = struct {
    /// a category for the values.
    category: union { discrete: "discrete", continuous: "continuous", mixed: "mixed" },
    /// every datum should hold a value for human's or computer's reading
    value: []const u8,
};
