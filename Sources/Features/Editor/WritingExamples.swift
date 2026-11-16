import Foundation

/// A static library of example wording the user can insert and then adapt.
/// Everything here is fictional and generic: no real employers, people or schools.
struct WritingExampleCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let items: [String]
}

enum WritingExamples {
    /// Professional summaries, grouped by field.
    static let summaryCategories: [WritingExampleCategory] = [
        WritingExampleCategory(id: "business", name: "Business and finance", items: [
            "Finance professional with eight years of experience in budgeting, forecasting and month-end reporting. Known for turning complex numbers into clear recommendations that leadership can act on.",
            "Operations manager who has led teams of up to 25 people across two sites. Focused on steady process improvement, accurate reporting and a calm, reliable working style.",
            "Business analyst with a background in retail and logistics. Skilled at finding the cause behind a trend and presenting it in plain language to non-technical colleagues."
        ]),
        WritingExampleCategory(id: "technology", name: "Technology", items: [
            "Software engineer with six years of experience building web and mobile products from first prototype to production. Comfortable owning a feature end to end, from design discussions to monitoring after release.",
            "Data analyst who combines SQL, spreadsheet modeling and clear visual reporting. Enjoys working with product and sales teams to answer practical questions with evidence.",
            "IT support specialist with five years of experience resolving hardware, software and access issues for teams of 200 or more. Patient, methodical and good at writing clear documentation."
        ]),
        WritingExampleCategory(id: "healthcare", name: "Healthcare", items: [
            "Registered nurse with seven years of experience in acute care. Calm under pressure, careful with documentation and committed to clear communication with patients and families.",
            "Medical administrator experienced in scheduling, records and insurance queries for a busy outpatient clinic. Organized, discreet and used to working with strict privacy requirements.",
            "Physiotherapy assistant who supports treatment plans, exercise programs and patient education. Reliable, encouraging and keen to keep learning alongside the clinical team."
        ]),
        WritingExampleCategory(id: "education", name: "Education", items: [
            "Primary school teacher with nine years of classroom experience. Plans lessons around how children actually learn and keeps parents informed with regular, honest feedback.",
            "Training coordinator who designs and delivers short workshops for new starters and team leads. Measures success by how well people use what they learned a month later.",
            "University tutor and researcher with experience marking, mentoring and presenting at seminars. Writes clearly and explains difficult ideas without talking down to anyone."
        ]),
        WritingExampleCategory(id: "marketing", name: "Marketing and creative", items: [
            "Marketing specialist with six years of experience in email, social and content. Combines a good eye for copy with a habit of checking the numbers after every campaign.",
            "Graphic designer who builds brand systems, packaging and digital assets for small and mid-sized companies. Works closely with clients and delivers tidy, well-labelled files.",
            "Content writer with a background in journalism. Researches carefully, writes to a brief and meets deadlines without drama."
        ]),
        WritingExampleCategory(id: "service", name: "Customer service and retail", items: [
            "Customer service lead with five years of experience in busy contact centers. Resolves problems on the first contact wherever possible and coaches new team members with patience.",
            "Retail supervisor who manages stock, scheduling and a team of 12. Known for tidy stores, friendly service and dependable cash handling.",
            "Hospitality professional with experience in restaurants and events. Quick, courteous and calm when the room is full."
        ]),
        WritingExampleCategory(id: "trades", name: "Trades, logistics and operations", items: [
            "Warehouse and logistics coordinator with six years of experience in receiving, picking and dispatch. Safety-minded, accurate with paperwork and comfortable with scanning systems.",
            "Qualified electrician with a clean safety record and experience in domestic and light commercial installations. Works neatly, explains the job to customers and finishes on schedule.",
            "Fleet and transport planner who builds efficient routes, manages driver schedules and keeps maintenance records current."
        ]),
        WritingExampleCategory(id: "entry", name: "Student and entry level", items: [
            "Recent graduate in business administration with internship experience in sales support. Quick to learn new tools, organized with deadlines and eager to contribute to a friendly, busy team.",
            "Final-year computer science student with two team projects and a part-time role in a campus help desk. Looking for a junior developer position where I can learn from experienced colleagues.",
            "Motivated school leaver with experience in volunteering and part-time retail work. Reliable, punctual and happy to be trained."
        ]),
        WritingExampleCategory(id: "change", name: "Career change", items: [
            "Former hospitality manager moving into customer success. Eight years of handling complaints, training teams and keeping regular customers happy carry over directly to this work.",
            "Teacher moving into learning and development. Experienced in planning, presenting and giving feedback, and recently completed a certificate in instructional design.",
            "Administrator returning to work after a career break of two years. Kept skills current through a bookkeeping course and volunteer treasurer duties."
        ])
    ]

    /// Achievement bullets, grouped by theme. Figures are examples: the user should replace them with their own.
    static let achievementCategories: [WritingExampleCategory] = [
        WritingExampleCategory(id: "leadership", name: "Leadership", items: [
            "Led a team of 12 across two shifts, reducing overtime by 15 percent through clearer scheduling.",
            "Coached four new team leads, all of whom were promoted or took on larger teams within a year.",
            "Introduced a weekly planning meeting that cut missed deadlines from about one a week to one a month.",
            "Took over a struggling project mid-year, reset priorities with the client and delivered on the revised date.",
            "Set up a simple handover checklist that removed repeat questions between shifts."
        ]),
        WritingExampleCategory(id: "sales", name: "Sales and accounts", items: [
            "Grew a portfolio of 40 accounts by 22 percent in 12 months through regular check-ins and tailored offers.",
            "Closed an average of eight new customers a month, consistently above the team target.",
            "Won back six lapsed customers by calling them directly and fixing the issues that made them leave.",
            "Prepared clear proposals and pricing sheets that shortened the average sales cycle by two weeks.",
            "Kept customer records current in the CRM, which made monthly forecasts more reliable."
        ]),
        WritingExampleCategory(id: "operations", name: "Operations and process", items: [
            "Cut order processing time from three days to one by rewriting the checklist and removing duplicate steps.",
            "Reduced stock errors by 30 percent after introducing weekly cycle counts.",
            "Negotiated new terms with two suppliers, saving about 9 percent on yearly costs.",
            "Documented 20 standard procedures so new starters could work independently within two weeks.",
            "Maintained a 99 percent on-time dispatch rate through peak season."
        ]),
        WritingExampleCategory(id: "technology", name: "Technology and engineering", items: [
            "Built a reporting tool that replaced a weekly manual spreadsheet and saved the team about six hours a week.",
            "Improved page load time by 40 percent by optimizing images and removing unused code.",
            "Wrote automated tests for the checkout flow, cutting regressions found after release by half.",
            "Migrated a customer database to a new system over a weekend with no data loss and under two hours of downtime.",
            "Reviewed code for a team of five and agreed a shared style guide that reduced review comments."
        ]),
        WritingExampleCategory(id: "service", name: "Customer service", items: [
            "Resolved an average of 60 customer contacts a day with a satisfaction rating above 90 percent.",
            "Wrote 15 help articles for the most common questions, reducing repeat contacts by about a fifth.",
            "Handled escalated complaints calmly and turned most of them into repeat customers.",
            "Trained eight new advisers and shared tips that shortened average call time by 45 seconds.",
            "Spotted a recurring billing problem and worked with finance to fix it for all affected customers."
        ]),
        WritingExampleCategory(id: "projects", name: "Project management", items: [
            "Delivered a 14-week office move for 80 people on time and within 3 percent of budget.",
            "Tracked risks and dependencies in a single plan that the whole team could see, which reduced status meetings.",
            "Coordinated five contractors and two internal teams without a missed milestone.",
            "Ran retrospectives after each phase and applied the findings to the next one.",
            "Wrote clear project updates for senior stakeholders every two weeks."
        ]),
        WritingExampleCategory(id: "marketing", name: "Marketing and communications", items: [
            "Grew the email list from 3,000 to 9,500 subscribers in a year through a new sign-up offer and clearer forms.",
            "Raised email open rates by 8 points by testing subject lines and send times.",
            "Wrote and edited 50 blog posts that brought in steady search traffic.",
            "Managed a social media calendar across three channels and increased engagement by 35 percent.",
            "Organized four customer events with an average of 120 attendees."
        ]),
        WritingExampleCategory(id: "finance", name: "Finance and administration", items: [
            "Prepared monthly management accounts and delivered them by the fifth working day.",
            "Found and corrected a recurring invoicing error that had been costing about 2 percent of monthly revenue.",
            "Processed over 400 invoices a month with a very low error rate.",
            "Built a simple budget tracker that gave department heads a clear view of spending.",
            "Handled travel, diaries and meeting preparation for five senior managers."
        ]),
        WritingExampleCategory(id: "teaching", name: "Teaching and training", items: [
            "Taught classes of 28 pupils and raised the share meeting reading targets from 70 to 85 percent.",
            "Designed a three-part induction workshop used for every new starter in the department.",
            "Gave written feedback within a week on every assignment, which students said they found useful.",
            "Created revision guides and practice questions shared with all classes in the year group.",
            "Mentored two trainee teachers through their first placement."
        ]),
        WritingExampleCategory(id: "healthcare", name: "Healthcare", items: [
            "Cared for up to eight patients per shift while keeping documentation accurate and up to date.",
            "Explained treatment plans in plain language to patients and families, and checked understanding before discharge.",
            "Supported the team during a ward reorganization by training colleagues on the new handover process.",
            "Maintained patient records in line with privacy rules and passed every internal audit.",
            "Took part in a quality project that reduced missed appointments by 12 percent."
        ]),
        WritingExampleCategory(id: "student", name: "Student and early career", items: [
            "Completed a final-year project on delivery routing, earning a first-class mark and a recommendation from my supervisor.",
            "Organized a student society of 60 members, including a termly speaker series.",
            "Worked 15 hours a week alongside full-time study without missing a deadline.",
            "Helped customers, handled cash and closed the shop on weekends in a part-time retail role.",
            "Volunteered at a local food bank, sorting donations and coordinating a rota of ten helpers."
        ])
    ]

    static var allSummaries: [String] { summaryCategories.flatMap { $0.items } }
    static var allAchievements: [String] { achievementCategories.flatMap { $0.items } }
}
