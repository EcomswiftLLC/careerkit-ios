import Foundation

// MARK: - Sample content
//
// Fictional people used for template previews and thumbnails. Names, employers,
// schools, numbers and results are invented. Each template gets a person who fits
// its category, industry and level. Templates meant for one page get the same person
// with the least important lines trimmed, so the sample is about one page long.

enum SampleContent {

    static let sampleLabel = "Sample content, fictional person"

    // MARK: Public API

    /// A fully populated fictional resume for a template. A new value (new ids) on every call.
    static func resume(for template: TemplateSpec) -> Resume {
        let person = persona(for: template)
        var sections: [ResumeSection] = []
        for kind in ResumeFactory.sectionKinds(for: template) {
            guard let section = person.sections[kind] else { continue }
            sections.append(section)
        }
        if template.typicalPages <= 1 {
            sections = fit(sections, budget: onePageWordBudget)
        }
        return Resume(
            title: "Sample resume",
            templateID: template.id,
            pageSize: .a4,
            personal: person.personal,
            sections: sections
        )
    }

    /// A sample cover letter written by the finance manager persona.
    static func coverLetter() -> CoverLetter {
        var letter = CoverLetter(title: "Sample cover letter", templateID: "ck.letter.corporate")
        letter.senderName = "Marcus Lindqvist"
        letter.senderTitle = "Finance Manager"
        letter.senderEmail = "marcus.lindqvist@example.com"
        letter.senderPhone = "+1 612 555 0183"
        letter.senderLocation = "Minneapolis, United States"
        letter.recipientName = "Helen Marsh"
        letter.recipientTitle = "Director of Finance"
        letter.companyName = "Alder Creek Foods"
        letter.companyAddress = "400 Mill Street, Saint Paul, MN"
        letter.jobTitle = "Senior Finance Manager"
        letter.jobDescription = "Lead the monthly close, own the annual budget and reforecasts, and partner with plant and sales leaders on margin."
        letter.greeting = "Dear Ms. Marsh,"
        letter.introduction = "I am writing to apply for the Senior Finance Manager role at Alder Creek Foods. I have spent nine years in manufacturing finance, and for the last six I have run the monthly close and the forecast for a 140 million dollar business unit."
        letter.experienceParagraph = "At Ridgeway Industrial Products I shortened the close from nine working days to five and built a rolling forecast that stayed within 2.5 percent of actual revenue for eight quarters in a row. I also found 3.4 million dollars of margin leakage in freight and scrap and tracked the recovery with each plant manager. Your posting mentions covenant reporting and plant partnering, and both are part of my current job."
        letter.interestParagraph = "Alder Creek's move into frozen meals raises the kind of costing questions I enjoy: which products really earn their shelf space, and what a change in packaging does to margin. I would like to help your plants and sales team answer those questions with numbers they trust."
        letter.closing = "I would welcome a conversation about the role. Thank you for your time and for considering my application."
        letter.signOff = "Sincerely,"
        return letter
    }

    // MARK: Persona selection

    private struct Persona {
        var personal: PersonalInfo
        var sections: [SectionKind: ResumeSection]
    }

    private static func persona(for template: TemplateSpec) -> Persona {
        switch template.id {
        case "ck.professional.executive", "ck.professional.business-elite", "ck.professional.senior-management":
            return operationsExecutive()
        case "ck.professional.corporate", "ck.professional.classic-professional", "ck.modern.professional-grid":
            return financeManager()
        case "ck.professional.modern-professional", "ck.technical.project-manager":
            return projectManager()
        case "ck.modern.modern-minimal", "ck.technical.product-manager":
            return productManager()
        case "ck.modern.contemporary", "ck.creative.marketing-professional", "ck.creative.editorial":
            return marketingLead()
        case "ck.modern.elegant":
            return nurse()
        case "ck.modern.modern-classic":
            return teacher()
        case "ck.modern.clean-lines", "ck.technical.software-engineer":
            return softwareEngineer()
        case "ck.creative.creative-designer", "ck.creative.visual-portfolio", "ck.creative.creative-minimal":
            return uxDesigner()
        case "ck.academic.academic-cv", "ck.academic.researcher", "ck.academic.scientific-cv":
            return researcher()
        case "ck.academic.university-graduate", "ck.entry.fresh-graduate":
            return graduate()
        case "ck.entry.student-resume", "ck.entry.internship-resume":
            return student()
        case "ck.entry.first-job":
            return firstJobSeeker()
        case "ck.technical.it-professional":
            return itAdministrator()
        case "ck.technical.data-analyst":
            return dataAnalyst()
        default:
            switch template.category {
            case .professional: return financeManager()
            case .modern: return productManager()
            case .creative: return uxDesigner()
            case .academic: return researcher()
            case .entryLevel: return graduate()
            case .technical: return softwareEngineer()
            }
        }
    }

    // MARK: Fitting one-page templates

    /// Word budget for a one-page sample. Two-page templates use the whole persona.
    private static let onePageWordBudget = 470

    private static func words(in section: ResumeSection) -> Int {
        var parts: [String] = [section.title, section.text]
        for item in section.entries {
            parts.append(item.heading)
            parts.append(item.subheading)
            parts.append(item.location)
            parts.append(item.detail)
            parts.append(item.extra)
            parts.append(contentsOf: item.bullets)
        }
        for group in section.skillGroups {
            parts.append(group.name)
            parts.append(contentsOf: group.items)
        }
        var total = 0
        for part in parts {
            total += part.split(separator: " ").count
        }
        return total
    }

    private static func totalWords(_ sections: [ResumeSection]) -> Int {
        var total = 0
        for section in sections { total += words(in: section) }
        return total
    }

    /// Removes the least important lines until the sections fit the budget.
    /// It never removes a whole section and never empties an entry list.
    private static func fit(_ sections: [ResumeSection], budget: Int) -> [ResumeSection] {
        var result = sections
        var passes = 0
        while totalWords(result) > budget && passes < 400 {
            passes += 1
            if !trimOnce(&result) { break }
        }
        return result
    }

    /// Finds the entry with the most bullets (later entries win ties) among kinds that hold bullets.
    private static func entryWithMostBullets(in sections: [ResumeSection], above minimum: Int) -> (section: Int, entry: Int)? {
        let bulletKinds: [SectionKind] = [.experience, .internships, .projects, .volunteer]
        var found: (section: Int, entry: Int)? = nil
        var bestCount = minimum
        for sectionIndex in sections.indices where bulletKinds.contains(sections[sectionIndex].kind) {
            let items = sections[sectionIndex].entries
            for entryIndex in items.indices {
                let count = items[entryIndex].bullets.count
                if count > minimum && count >= bestCount {
                    found = (sectionIndex, entryIndex)
                    bestCount = count
                }
            }
        }
        return found
    }

    private static func trimOnce(_ sections: inout [ResumeSection]) -> Bool {
        // 1. Long bullet lists lose their last bullet first, down to two.
        if let target = entryWithMostBullets(in: sections, above: 2) {
            sections[target.section].entries[target.entry].bullets.removeLast()
            return true
        }
        // 2. Extra sections keep two entries (three for publications).
        let extraKinds: [SectionKind] = [.awards, .memberships, .courses, .volunteer, .certifications, .projects, .publications, .references]
        for index in sections.indices.reversed() {
            let kind = sections[index].kind
            if !extraKinds.contains(kind) { continue }
            let limit = kind == .publications ? 3 : 2
            if sections[index].entries.count > limit {
                sections[index].entries.removeLast()
                return true
            }
        }
        // 3. Older jobs beyond the third go next.
        for index in sections.indices {
            let kind = sections[index].kind
            if (kind == .experience || kind == .internships) && sections[index].entries.count > 3 {
                sections[index].entries.removeLast()
                return true
            }
        }
        // 4. At most four skill groups and two education entries.
        for index in sections.indices {
            if sections[index].kind == .skills && sections[index].skillGroups.count > 4 {
                sections[index].skillGroups.removeLast()
                return true
            }
            if sections[index].kind == .education && sections[index].entries.count > 2 {
                sections[index].entries.removeLast()
                return true
            }
        }
        // 5. Last resort: shorten bullet lists to one bullet per entry.
        if let target = entryWithMostBullets(in: sections, above: 1) {
            sections[target.section].entries[target.entry].bullets.removeLast()
            return true
        }
        return false
    }

    // MARK: Builders

    private static func date(_ year: Int, _ month: Int? = nil) -> MonthYear {
        return MonthYear(year: year, month: month)
    }

    private static func entry(
        _ heading: String,
        _ subheading: String,
        _ location: String = "",
        from: MonthYear? = nil,
        to: MonthYear? = nil,
        current: Bool = false,
        detail: String = "",
        extra: String = "",
        bullets: [String] = []
    ) -> ResumeEntry {
        var item = ResumeEntry()
        item.heading = heading
        item.subheading = subheading
        item.location = location
        item.start = from
        item.end = to
        item.isCurrent = current
        item.detail = detail
        item.extra = extra
        item.bullets = bullets
        return item
    }

    private static func textSection(_ kind: SectionKind, _ value: String) -> ResumeSection {
        var section = ResumeSection(kind: kind)
        section.text = value
        return section
    }

    private static func entrySection(_ kind: SectionKind, _ items: [ResumeEntry]) -> ResumeSection {
        var section = ResumeSection(kind: kind)
        section.entries = items
        return section
    }

    private static func groupSection(_ kind: SectionKind, _ groups: [(String, [String])]) -> ResumeSection {
        var section = ResumeSection(kind: kind)
        section.skillGroups = groups.map { (pair: (String, [String])) -> SkillGroup in
            SkillGroup(name: pair.0, items: pair.1)
        }
        return section
    }

    private static func contact(
        name: String, title: String, email: String, phone: String,
        city: String, country: String, website: String = "", portfolio: String = ""
    ) -> PersonalInfo {
        var info = PersonalInfo()
        info.fullName = name
        info.professionalTitle = title
        info.email = email
        info.phone = phone
        info.city = city
        info.country = country
        info.website = website
        info.portfolio = portfolio
        return info
    }

    // MARK: Personas, senior and mid career

    private static func operationsExecutive() -> Persona {
        let personal = contact(
            name: "Daniela Whitcombe", title: "Chief Operating Officer",
            email: "daniela.whitcombe@example.com", phone: "+1 312 555 0147",
            city: "Chicago", country: "United States", website: "danielawhitcombe.example")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Operations executive with 18 years in freight and supply chain. Has run networks of up to 2,400 people across three regions, cut cost per shipment by 14 percent and led two acquisitions through integration. Known for setting a few clear priorities and for building leadership teams that keep the results after she moves on. Reports to the chief executive, chairs the operating committee and has led the company through three peak seasons, two acquisitions and a labor contract renewal.")
        s[.experience] = entrySection(.experience, [
            entry("Chief Operating Officer", "Harbourline Freight Group", "Chicago, IL", from: date(2021, 3), current: true, detail: "Reports to the chief executive. Responsible for 31 terminals, fleet maintenance, customer service, safety and procurement.", bullets: [
                "Run day-to-day operations for 2,400 employees across 31 terminals with a 410 million dollar operating budget.",
                "Cut cost per shipment by 14 percent over three years by consolidating routes and renegotiating 22 carrier contracts.",
                "Raised on-time delivery from 91.2 to 96.8 percent after introducing a weekly terminal scorecard reviewed by every site leader.",
                "Led the integration of two acquired carriers in 11 months and kept 94 percent of their managers.",
                "Chair the monthly operating review and agree yearly targets for safety, service and cost with each regional vice president.",
                "Rebuilt the capital plan, moving 60 million dollars toward dock doors and terminal automation with the fastest payback.",
                "Created a leadership program for 40 terminal managers; 31 completed the first two cohorts and 9 were promoted."]),
            entry("Vice President, Operations", "Northgate Logistics", "Columbus, OH", from: date(2016, 6), to: date(2021, 2), detail: "Regional operations leader reporting to the chief operating officer, with 14 distribution centers and 900 staff.", bullets: [
                "Managed a 180 million dollar regional network of 14 distribution centers and 900 staff.",
                "Introduced slotting and labor planning tools that lifted pick rates by 19 percent without adding headcount.",
                "Reduced lost-time injuries by 38 percent with a site safety program built together with floor supervisors.",
                "Mentored six directors, four of whom were promoted to vice president or general manager.",
                "Negotiated a five-year labor agreement covering 400 employees with no work stoppage.",
                "Piloted a returns processing center that cut returns cycle time from 12 days to 5."]),
            entry("Director of Distribution", "Brightwell Supply Co.", "Indianapolis, IN", from: date(2012, 1), to: date(2016, 5), detail: "Responsible for nine distribution centers serving 1,100 retail stores in the Midwest.", bullets: [
                "Opened two distribution centers on schedule and 6 percent under a 38 million dollar capital budget.",
                "Standardized receiving and returns at nine sites, cutting dock-to-stock time from 31 to 19 hours.",
                "Negotiated a three-year warehouse lease program that saved 2.1 million dollars.",
                "Built the first company-wide operations review, still held every month.",
                "Hired and developed eight site managers, six of whom still lead sites at the company."]),
            entry("Operations Manager", "Brightwell Supply Co.", "Indianapolis, IN", from: date(2008, 8), to: date(2011, 12), bullets: [
                "Supervised 120 staff on three shifts at the Indianapolis hub.",
                "Built a cross-training plan that reduced overtime by 22 percent.",
                "Introduced daily huddles and a visual board that cut mis-shipments by half.",
                "Ran the hub peak season plan for four years with no missed customer cut-offs.",
                "Cut inventory write-offs from 1.4 million to 0.6 million dollars a year with monthly cycle counts.",
                "Trained 14 shift leaders in coaching and conflict resolution."]),
            entry("Operations Analyst", "Kestrel Parcel", "Chicago, IL", from: date(2006, 6), to: date(2008, 7), bullets: [
                "Modeled route and staffing scenarios for 40 delivery stations.",
                "Found 1.2 million dollars of yearly savings in fuel and overtime.",
                "Built the weekly service report used by regional directors until 2012."])
        ])
        s[.education] = entrySection(.education, [
            entry("Master of Business Administration, Operations Management", "Lakeshore School of Business", "Chicago, IL", from: date(2009), to: date(2011), extra: "Evening program, completed while working full time", bullets: [
                "Capstone: redesigned the pick-and-pack flow for a regional grocer, making it 17 percent faster."]),
            entry("Bachelor of Science, Industrial Engineering", "Midvale State University", "Midvale, OH", from: date(2002), to: date(2006), extra: "Graduated with honors")
        ])
        s[.skills] = groupSection(.skills, [
            ("Leadership", ["P&L ownership", "Board reporting", "Succession planning", "Change management"]),
            ("Operations", ["Network design", "Lean operations", "Capacity planning", "Safety programs"]),
            ("Finance and deals", ["Budgeting and forecasting", "Capital projects", "Contract negotiation", "Acquisition integration"]),
            ("Industry knowledge", ["Truckload and parcel networks", "Warehousing", "Last-mile delivery", "Cross-border freight"])
        ])
        s[.certifications] = entrySection(.certifications, [
            entry("Certified Supply Chain Professional", "Association for Logistics Standards", from: date(2012)),
            entry("Lean Six Sigma Black Belt", "Process Excellence Council", from: date(2013))
        ])
        s[.memberships] = entrySection(.memberships, [
            entry("Member, Logistics Executives Forum", "", "Chicago, IL", from: date(2017), current: true),
            entry("Board Member", "Westside Food Pantry", "Chicago, IL", from: date(2019), current: true, detail: "Chairs the finance committee and oversees a 1.4 million dollar annual budget.")
        ])
        s[.awards] = entrySection(.awards, [
            entry("Operations Leader of the Year", "Midwest Logistics Council", from: date(2023)),
            entry("Forty Under 40 in Transport", "Regional Freight Review", from: date(2014)),
            entry("Safety Leadership Award", "Midwest Logistics Council", from: date(2019))
        ])
        s[.languages] = groupSection(.languages, [("", ["English, native", "Spanish, professional working"])])
        return Persona(personal: personal, sections: s)
    }

    private static func financeManager() -> Persona {
        let personal = contact(
            name: "Marcus Lindqvist", title: "Finance Manager",
            email: "marcus.lindqvist@example.com", phone: "+1 612 555 0183",
            city: "Minneapolis", country: "United States")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Finance manager with nine years in manufacturing and distribution. Owns the monthly close, forecasting and cost reporting for a 140 million dollar business unit and works with plant and sales leaders to turn variances into decisions. Has led two system migrations and three small supplier acquisitions through diligence and onboarding, and coaches new accountants through their first year.")
        s[.experience] = entrySection(.experience, [
            entry("Finance Manager", "Ridgeway Industrial Products", "Minneapolis, MN", from: date(2020, 2), current: true, detail: "Reports to the vice president of finance. Partners with four plant managers, the sales director and the treasurer.", bullets: [
                "Lead a team of five accountants and analysts that closes the books in 5 working days, down from 9.",
                "Built a rolling 12-month forecast that held revenue variance within 2.5 percent for eight straight quarters.",
                "Found 3.4 million dollars of margin leakage in freight and scrap and tracked the recovery with plant managers.",
                "Prepare board and lender packs, including covenant calculations for a 45 million dollar credit facility.",
                "Introduced a monthly pricing review with sales that raised gross margin by 1.3 points.",
                "Led the move to a new planning system, finished in four months with no missed closes.",
                "Built a capital request template that shortened approvals from 18 days to 7.",
                "Hired and developed two analysts; one was promoted to senior analyst within 18 months."]),
            entry("Senior Financial Analyst", "Ridgeway Industrial Products", "Minneapolis, MN", from: date(2017, 6), to: date(2020, 1), detail: "Supported pricing, supply chain and sales for three product lines worth 90 million dollars.", bullets: [
                "Produced product-line profitability reports for 600 SKUs used in the annual pricing review.",
                "Automated 14 recurring reports in the planning tool, saving about 60 analyst hours a month.",
                "Built the model and diligence checklist for the purchase of a packaging plant.",
                "Trained 12 plant supervisors to read their own cost reports.",
                "Supported two annual budget cycles and shortened the turnaround by 15 percent.",
                "Created a freight cost model comparing 11 carriers that informed a 700,000 dollar yearly saving.",
                "Presented quarterly business reviews to the plant leadership team."]),
            entry("Financial Analyst", "Calder Moss Distribution", "Saint Paul, MN", from: date(2015, 7), to: date(2017, 5), bullets: [
                "Reconciled intercompany balances across four entities with no audit adjustments in two years.",
                "Prepared weekly cash reports and a 13-week cash forecast.",
                "Cut the monthly accrual review from three days to one by standardizing support files.",
                "Reduced days sales outstanding from 52 to 44 through weekly collections reviews with sales.",
                "Documented 22 month-end procedures that new staff still use."]),
            entry("Staff Accountant", "Hollis & Pryor LLP", "Minneapolis, MN", from: date(2013, 8), to: date(2015, 6), bullets: [
                "Completed audit fieldwork for 12 mid-sized clients in manufacturing and retail.",
                "Drafted workpapers and footnote disclosures reviewed by two audit partners.",
                "Prepared tax workpapers for eight clients and helped with year-end filings."]),
            entry("Accounting Intern", "Hollis & Pryor LLP", "Minneapolis, MN", from: date(2012, 6), to: date(2012, 8), bullets: [
                "Tested 150 sales invoices for an inventory audit and reported two control gaps.",
                "Filed and indexed audit documentation for six clients."])
        ])
        s[.education] = entrySection(.education, [
            entry("Master of Science, Finance", "Lakeview Business Institute", "Minneapolis, MN", from: date(2018), to: date(2020), detail: "Thesis on working capital management in mid-sized manufacturers.", extra: "Evening program"),
            entry("Bachelor of Arts, Accounting", "Northfield Valley University", "Northfield, MN", from: date(2009), to: date(2013), extra: "GPA 3.7 of 4.0")
        ])
        s[.skills] = groupSection(.skills, [
            ("Finance", ["Month-end close", "Forecasting and budgeting", "Variance analysis", "Cost accounting"]),
            ("Systems", ["ERP general ledger", "Spreadsheet modeling", "SQL queries", "Dashboards"]),
            ("Working with others", ["Plant partnering", "Board reporting", "Team coaching"]),
            ("Reporting", ["Board and lender packs", "Management commentary", "Covenant compliance"])
        ])
        s[.certifications] = entrySection(.certifications, [
            entry("Certified Public Accountant", "State Board of Accountancy", from: date(2016)),
            entry("Corporate Finance Certificate", "Lakeview Business Institute", from: date(2019))
        ])
        s[.awards] = entrySection(.awards, [
            entry("Finance Team of the Year", "Ridgeway Industrial Products", from: date(2023)),
            entry("Spot Award for close process redesign", "Ridgeway Industrial Products", from: date(2021)),
            entry("Employee of the Quarter", "Calder Moss Distribution", from: date(2016))
        ])
        s[.languages] = groupSection(.languages, [("", ["English, native", "Swedish, conversational"])])
        return Persona(personal: personal, sections: s)
    }

    private static func projectManager() -> Persona {
        let personal = contact(
            name: "Tomas Ibarra", title: "Senior Project Manager",
            email: "tomas.ibarra@example.com", phone: "+1 303 555 0126",
            city: "Denver", country: "United States")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Project manager with 11 years delivering software rollouts and facility upgrades for healthcare and logistics organizations. Typical scope is 1 to 6 million dollars, 8 to 30 people and 6 to 14 months. Comfortable reporting to executives and running the weekly details with the team. Has taken over two stalled projects and returned both to green status within a quarter.")
        s[.experience] = entrySection(.experience, [
            entry("Senior Project Manager", "Summit Health Network", "Denver, CO", from: date(2019, 4), current: true, detail: "Portfolio owner for clinical systems projects across 18 clinics. Reports to the chief information officer.", bullets: [
                "Delivered a patient scheduling platform to 18 clinics on time and 3 percent under a 4.2 million dollar budget.",
                "Manage a portfolio of five projects with a team of 22 across IT, clinical operations and vendors.",
                "Cut average change-request turnaround from 11 to 4 days by introducing a weekly decision log.",
                "Trained 40 clinic managers on go-live procedures; 97 percent joined a practice session.",
                "Cut vendor spend by 380,000 dollars by renegotiating three support contracts.",
                "Introduced lessons-learned reviews after each go-live; the PMO adopted nine of the recommendations."]),
            entry("Project Manager", "Rockline Distribution", "Aurora, CO", from: date(2015, 9), to: date(2019, 3), detail: "Delivered projects for five distribution centers handling 2,400 orders a day.", bullets: [
                "Led a warehouse management system replacement across 6 sites with no missed shipping days.",
                "Kept a shared risk register that flagged a vendor delay six weeks early.",
                "Halved reporting time with a single status template adopted by all project managers.",
                "Coordinated 14 vendors and two internal teams through four go-lives.",
                "Finished all four projects within 2 percent of budget.",
                "Wrote the cutover checklist that later became the company standard."]),
            entry("Assistant Project Manager", "Fenwick Building Group", "Denver, CO", from: date(2012, 6), to: date(2015, 8), bullets: [
                "Coordinated subcontractors on a 12 million dollar office renovation delivered in 10 months.",
                "Maintained schedules, RFIs and submittals for three concurrent projects.",
                "Cut punch-list closeout from 5 weeks to 3 with a room-by-room checklist.",
                "Reduced change-order disputes by 30 percent with a written approval log."]),
            entry("Project Coordinator", "Fenwick Building Group", "Denver, CO", from: date(2010, 7), to: date(2012, 5), bullets: [
                "Tracked permits, deliveries and inspections for residential and light commercial jobs.",
                "Wrote the weekly owner update for six active projects.",
                "Kept a punch list for each house and closed 95 percent before handover."])
        ])
        s[.education] = entrySection(.education, [
            entry("Bachelor of Science, Business Administration", "Front Range State University", "Fort Collins, CO", from: date(2006), to: date(2010), extra: "Minor in Management Information Systems")
        ])
        s[.skills] = groupSection(.skills, [
            ("Delivery", ["Scope and schedule control", "Risk management", "Budget tracking", "Vendor management"]),
            ("Methods", ["Agile and waterfall", "Stakeholder reporting", "Change control", "Go-live planning"]),
            ("Tools", ["Gantt scheduling", "Issue trackers", "Spreadsheet reporting"]),
            ("Reporting", ["Executive dashboards", "Weekly status notes", "Budget variance reports"])
        ])
        s[.certifications] = entrySection(.certifications, [
            entry("Certified Project Delivery Professional", "Institute for Delivery Practice", from: date(2016)),
            entry("Agile Delivery Practitioner", "Delivery Practice Institute", from: date(2018)),
            entry("Risk Management Practitioner", "Delivery Practice Institute", from: date(2020))
        ])
        s[.projects] = entrySection(.projects, [
            entry("Patient Scheduling Rollout", "Summit Health Network", from: date(2021), to: date(2022), detail: "18 clinics, 4.2 million dollars, 14 months.", bullets: [
                "Ran the steering group, the vendor contract and the clinic training plan."]),
            entry("Warehouse System Replacement", "Rockline Distribution", from: date(2017), to: date(2018), detail: "6 sites, 1.8 million dollars, 9 months.", bullets: [
                "Planned each cutover over a weekend to protect customer shipments."]),
            entry("Clinic Network Upgrade", "Summit Health Network", from: date(2020), to: date(2021), detail: "Replaced network equipment at 18 clinics over six weekends.", bullets: [
                "Scheduled each clinic outside opening hours, so no clinic closed for the upgrade."])
        ])
        s[.languages] = groupSection(.languages, [("", ["English, native", "Spanish, intermediate"])])
        return Persona(personal: personal, sections: s)
    }

    private static func productManager() -> Persona {
        let personal = contact(
            name: "Aisha Rahman", title: "Senior Product Manager",
            email: "aisha.rahman@example.com", phone: "+1 206 555 0171",
            city: "Seattle", country: "United States", website: "aisharahman.example")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Product manager with eight years in small business software. Owns an invoicing product used by 38,000 businesses and makes roadmap decisions from customer interviews and usage data. Works best with a small squad, a clear goal and a short feedback loop. Started as an analyst, so can write a query and read an experiment result without waiting for a data team.")
        s[.experience] = entrySection(.experience, [
            entry("Senior Product Manager", "Orchard Ledger", "Seattle, WA", from: date(2021, 1), current: true, detail: "Owns the roadmap, pricing inputs and launches for invoicing and payments. Works with design, engineering, support and sales.", bullets: [
                "Own the invoicing product used by 38,000 small businesses and set the quarterly roadmap with support and sales.",
                "Shipped automatic payment reminders that cut average days-to-paid from 29 to 22 and lifted weekly active use by 11 percent.",
                "Reduced onboarding from 14 steps to 8, raising week-one activation from 41 to 52 percent.",
                "Lead a squad of 7 engineers and 1 designer, and mentor two associate product managers.",
                "Run a monthly call with 12 accountants and bookkeepers who rely on the product.",
                "Worked with finance to price a new tier; revenue per account rose 9 percent.",
                "Present quarterly product reviews to the executive team and the board."]),
            entry("Product Manager", "Orchard Ledger", "Seattle, WA", from: date(2018, 5), to: date(2020, 12), detail: "Product contact for reporting, bank connections and the mobile app.", bullets: [
                "Launched bank feed connections for six banks in five months; 60 percent of paying accounts adopted them.",
                "Wrote requirements and acceptance tests that reduced post-release defects by 30 percent.",
                "Ran 45 customer interviews that reshaped the reporting roadmap.",
                "Set up a monthly review of churned accounts with customer support.",
                "Defined success metrics for every release and reviewed them 30 days after launch.",
                "Handled about 180 support escalations a year and cut repeat escalations by a third."]),
            entry("Associate Product Manager", "Harbor Retail Tech", "Seattle, WA", from: date(2016, 8), to: date(2018, 4), bullets: [
                "Managed the backlog for the store pickup feature across web and mobile.",
                "Built SQL dashboards for conversion and pickup times used in weekly reviews.",
                "Cut pickup wait time from 22 to 12 minutes with a ready-by notification.",
                "Ran weekly sprint reviews with six engineers and two store operations leads."]),
            entry("Business Analyst", "Harbor Retail Tech", "Seattle, WA", from: date(2014, 7), to: date(2016, 7), bullets: [
                "Documented checkout flows for 120 stores and found 9 recurring causes of failed payments.",
                "Presented the findings to leadership, which led to a new payment retry rule.",
                "Interviewed store managers about pain points; the findings shaped the first pickup feature."])
        ])
        s[.education] = entrySection(.education, [
            entry("Bachelor of Science, Information Systems", "Cascade Coast University", "Tacoma, WA", from: date(2010), to: date(2014), bullets: [
                "Capstone: an inventory tracking app for a campus food pantry, still used by volunteers."])
        ])
        s[.skills] = groupSection(.skills, [
            ("Product", ["Roadmapping", "Discovery interviews", "Prioritization", "Pricing and packaging"]),
            ("Data", ["SQL", "Funnel analysis", "A/B testing", "Dashboards"]),
            ("Collaboration", ["Stakeholder alignment", "Technical specs", "Release planning"]),
            ("Technical", ["API basics", "Event tracking plans", "Data models"])
        ])
        s[.projects] = entrySection(.projects, [
            entry("Payment Reminders", "Orchard Ledger", from: date(2022), detail: "Reminders by email and text, sent on a schedule the business owner sets.", bullets: [
                "Tested three message styles with 9,000 invoices before choosing the final one."]),
            entry("Open Bank Feeds", "Orchard Ledger", from: date(2019), detail: "Automatic transaction import from six banks.", bullets: [
                "Agreed the data format with the banks and sequenced the rollout by customer volume."]),
            entry("Self-serve Onboarding Rebuild", "Orchard Ledger", from: date(2023), detail: "A shorter setup flow with sample data.", bullets: [
                "Measured activation weekly and removed steps that more than 15 percent of people skipped."])
        ])
        s[.awards] = entrySection(.awards, [
            entry("Product Excellence Award", "Orchard Ledger", from: date(2022)),
            entry("Customer Champion Award", "Orchard Ledger", from: date(2019)),
            entry("Internal Hackathon Winner", "Orchard Ledger", from: date(2020))
        ])
        return Persona(personal: personal, sections: s)
    }

    private static func marketingLead() -> Persona {
        let personal = contact(
            name: "Tessa Okafor", title: "Marketing Lead",
            email: "tessa.okafor@example.com", phone: "+1 512 555 0159",
            city: "Austin", country: "United States", portfolio: "tessaokafor.example")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Marketing lead for a direct-to-consumer home goods brand. Eight years across content, lifecycle email and paid media, with a habit of testing small ideas before spending on big ones. Leads a team of six and reports results to the founders every month. Writes briefs that designers and freelancers can follow without a meeting.")
        s[.experience] = entrySection(.experience, [
            entry("Marketing Lead", "Fernhill Home Goods", "Austin, TX", from: date(2021, 3), current: true, detail: "Reports to the co-founders. Responsible for brand, website content, email, paid media and creator partnerships.", bullets: [
                "Lead six people across content, paid media and lifecycle email for a brand with 48 million dollars in yearly revenue.",
                "Rebuilt the email program with segmented flows; email now brings 31 percent of sales, up from 22.",
                "Lowered blended acquisition cost by 18 percent by moving a quarter of paid spend to search and creator partnerships.",
                "Ran a spring campaign that drew 1.9 million site visits and 4,300 new customers in six weeks.",
                "Manage a 2.1 million dollar marketing budget and report spend against revenue every week.",
                "Hired and trained two lifecycle marketers who now run the abandoned cart and win-back flows.",
                "Wrote a brand voice guide and a photo style guide now used by 14 freelancers."]),
            entry("Senior Content Marketer", "Trailhead Outfitters", "Denver, CO", from: date(2018, 2), to: date(2021, 2), detail: "Owned the guides, video and newsletter content for an outdoor gear retailer with 60 stores.", bullets: [
                "Grew organic traffic from 120,000 to 410,000 monthly visits in two years with a refreshed guides library.",
                "Edited eight freelance writers and cut article turnaround from 14 days to 6.",
                "Produced a 12-part video series that reached 380,000 views.",
                "Set up a quarterly content audit that retired 140 weak pages.",
                "Worked with sales to produce 24 retailer training guides.",
                "Trained customer support on the guides, which cut email enquiries by 15 percent."]),
            entry("Marketing Specialist", "Juniper & Pine Co.", "Austin, TX", from: date(2015, 6), to: date(2018, 1), bullets: [
                "Managed the monthly newsletter and the social calendar for three brands.",
                "Tested subject lines on 70,000 subscribers; the winning style lifted opens by 8 points.",
                "Wrote product pages for 300 items using a shared tone guide.",
                "Built the first referral program, which brought in 900 customers in six months."]),
            entry("Communications Assistant", "Austin Arts Alliance", "Austin, TX", from: date(2013, 9), to: date(2015, 5), bullets: [
                "Wrote event announcements and member emails for 11 local arts groups.",
                "Photographed and posted 60 events a year.",
                "Grew the alliance newsletter list from 1,200 to 3,400 readers."])
        ])
        s[.education] = entrySection(.education, [
            entry("Bachelor of Arts, Communication", "Southwest Plains University", "Lubbock, TX", from: date(2009), to: date(2013), extra: "Minor in Design", bullets: [
                "Editor of the student magazine for two years, with a staff of 20 volunteers."])
        ])
        s[.skills] = groupSection(.skills, [
            ("Marketing", ["Brand strategy", "Campaign planning", "Lifecycle email", "Paid search and social"]),
            ("Content", ["Editing", "Search optimization", "Video scripting", "Photo direction"]),
            ("Analytics", ["Attribution reporting", "Spreadsheet modeling", "Survey design"]),
            ("Tools and reporting", ["Email platform administration", "Analytics dashboards", "Project tracking"])
        ])
        s[.certifications] = entrySection(.certifications, [
            entry("Digital Marketing Analytics Certificate", "Online Marketing Institute", from: date(2019)),
            entry("Email Deliverability Workshop", "Lifecycle Marketing Guild", from: date(2022))
        ])
        s[.projects] = entrySection(.projects, [
            entry("Spring Table Campaign", "Fernhill Home Goods", from: date(2023), detail: "Photo-led campaign across email, search and creator posts.", bullets: [
                "Produced the creative brief, a 30-day calendar and a daily results sheet."]),
            entry("Guides Library Rebuild", "Trailhead Outfitters", from: date(2019), detail: "Rewrote 60 buying guides with clearer structure and new photography."),
            entry("Referral Program Launch", "Juniper & Pine Co.", from: date(2017), detail: "A two-sided referral offer promoted by email and in the packaging insert.")
        ])
        s[.awards] = entrySection(.awards, [
            entry("Best Email Program, Retail", "Direct Commerce Awards", from: date(2023)),
            entry("Content Team of the Year", "Trailhead Outfitters", from: date(2020))
        ])
        s[.publications] = entrySection(.publications, [
            entry("How We Cut Email Unsubscribes by a Third", "Direct Commerce Journal", from: date(2023)),
            entry("A Plain Guide to Attribution", "Marketing Practice Review", from: date(2021)),
            entry("Writing for Search Without Writing for Robots", "Content Craft Quarterly", from: date(2019)),
            entry("What We Learned From 400 Product Reviews", "Direct Commerce Journal", from: date(2022))
        ])
        s[.languages] = groupSection(.languages, [("", ["English, native", "French, intermediate"])])
        return Persona(personal: personal, sections: s)
    }

    private static func nurse() -> Persona {
        let personal = contact(
            name: "Grace Mwangi", title: "Registered Nurse, Step-Down Unit",
            email: "grace.mwangi@example.com", phone: "+1 614 555 0138",
            city: "Columbus", country: "United States")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Registered nurse with eight years in medical-surgical and step-down care. Charge nurse on a 28-bed unit, comfortable with telemetry, rapid response and family communication. Teaches new graduates and keeps handoffs short and complete. Volunteers at community health fairs and mentors nursing students.")
        s[.experience] = entrySection(.experience, [
            entry("Charge Nurse, Step-Down Unit", "Riverbend Medical Center", "Columbus, OH", from: date(2021, 6), current: true, detail: "Unit for patients moving out of intensive care, with telemetry on 18 of 28 beds.", bullets: [
                "Lead shifts of 11 nurses and 4 aides on a 28-bed unit, assigning patients by acuity and skill.",
                "Cut patient falls from 9 to 3 a year with hourly rounding and bed alarm checks.",
                "Precept two to three new graduate nurses each year; 90 percent finish orientation on schedule.",
                "Coordinate rapid response calls with the intensive care team; the team reaches the bedside in under 4 minutes on average."]),
            entry("Staff Nurse, Medical-Surgical", "Saint Aldric Hospital", "Columbus, OH", from: date(2018, 3), to: date(2021, 5), detail: "Surgical floor with orthopedic, general and vascular patients.", bullets: [
                "Cared for five to six patients per shift on a 32-bed surgical floor.",
                "Wrote the unit discharge checklist that lowered 30-day readmissions on the floor from 14 to 11 percent.",
                "Served on the unit council that moved medication rounds to barcode scanning.",
                "Taught discharge instructions to about 12 patients a week using a plain-language handout I wrote."]),
            entry("Graduate Nurse", "Saint Aldric Hospital", "Columbus, OH", from: date(2016, 7), to: date(2018, 2), bullets: [
                "Completed a 12-week residency in medical-surgical nursing.",
                "Rotated through cardiac and oncology units before taking a permanent post.",
                "Completed 480 supervised clinical hours across four units."]),
            entry("Nursing Assistant (part time)", "Maple Grove Care Home", "Columbus, OH", from: date(2013, 5), to: date(2016, 5), bullets: [
                "Helped 12 residents each shift with bathing, meals and mobility.",
                "Recorded vital signs and reported changes to the nurse in charge."])
        ])
        s[.education] = entrySection(.education, [
            entry("Bachelor of Science in Nursing", "Westfield University School of Nursing", "Columbus, OH", from: date(2012), to: date(2016), extra: "Graduated cum laude", bullets: [
                "Honors project on fall prevention for older adults, presented at a regional student conference."])
        ])
        s[.skills] = groupSection(.skills, [
            ("Clinical", ["Telemetry monitoring", "IV therapy", "Wound care", "Discharge planning"]),
            ("Communication", ["Patient education", "Family updates", "Shift handoff"]),
            ("Systems", ["Electronic health records", "Medication barcode scanning"]),
            ("Leadership", ["Shift assignment", "Preceptorship", "Quality improvement"])
        ])
        s[.certifications] = entrySection(.certifications, [
            entry("Registered Nurse License", "State Board of Nursing", from: date(2016)),
            entry("Basic Life Support", "National Resuscitation Council", from: date(2024)),
            entry("Advanced Cardiac Life Support", "National Resuscitation Council", from: date(2024)),
            entry("Stroke Care Certificate", "Regional Nursing Association", from: date(2023))
        ])
        s[.volunteer] = entrySection(.volunteer, [
            entry("Volunteer Nurse", "Eastside Neighborhood Clinic", "Columbus, OH", from: date(2019), current: true, detail: "Runs blood pressure screening and diabetes education at four health fairs a year, reaching about 150 residents."),
            entry("Mentor", "Westfield Future Nurses Club", "Columbus, OH", from: date(2022), current: true, detail: "Meets monthly with nursing students to practice interviews and clinical questions.")
        ])
        return Persona(personal: personal, sections: s)
    }

    private static func teacher() -> Persona {
        let personal = contact(
            name: "Claire Hartley", title: "Head of Mathematics",
            email: "claire.hartley@example.com", phone: "+44 113 555 0142",
            city: "Leeds", country: "United Kingdom")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Secondary mathematics teacher with 15 years in the classroom and six as head of department. Builds clear schemes of work, supports colleagues through observation and coaching, and uses assessment data to decide where to intervene. Writes clear revision resources and has helped students from varied backgrounds reach grade 6 and above.")
        s[.experience] = entrySection(.experience, [
            entry("Head of Mathematics", "Ashgrove Academy", "Leeds, UK", from: date(2019, 9), current: true, detail: "Responsible for 1,150 students and nine staff. Reports to the deputy head for teaching and learning.", bullets: [
                "Lead a department of nine teachers and 1,150 students from Year 7 to Year 13.",
                "Raised the share of students reaching a standard pass in GCSE mathematics from 68 to 79 percent in three years.",
                "Introduced termly low-stakes quizzes and a short intervention cycle for students below target.",
                "Coach three early-career teachers each year through lesson observation and shared planning.",
                "Designed a Year 7 transition unit with feeder primary schools; six schools now use it.",
                "Manage a 40,000 pound resources budget and the department improvement plan.",
                "Introduced weekly moderation of student work, which halved marking differences between classes."]),
            entry("Mathematics Teacher", "Calderwood Secondary School", "Wakefield, UK", from: date(2014, 9), to: date(2019, 8), detail: "Classroom teacher and examination lead in a school of 900 students.", bullets: [
                "Taught Years 7 to 13, including further mathematics for small A-level groups.",
                "Ran a weekly after-school club that doubled attendance at the regional team challenge.",
                "Wrote the Year 9 scheme of work now used by all classes.",
                "Acted as exams officer for mathematics for three years.",
                "Led the move to online homework; 92 percent of students now submit on time.",
                "Prepared Year 11 groups for GCSE; 82 percent met or beat their target grade in 2019."]),
            entry("Mathematics Teacher", "Millbrook School", "Bradford, UK", from: date(2011, 9), to: date(2014, 8), bullets: [
                "Completed the induction year and taught Years 7 to 11.",
                "Created a set of revision videos used by the whole year group.",
                "Ran the Year 8 mathematics trip to a science museum for 90 students."]),
            entry("Teaching Assistant", "Hillcrest Primary School", "Leeds, UK", from: date(2010, 9), to: date(2011, 6), bullets: [
                "Supported small groups in numeracy and ran a homework club twice a week."])
        ])
        s[.education] = entrySection(.education, [
            entry("Postgraduate Certificate in Education, Secondary Mathematics", "Pennine University", "Huddersfield, UK", from: date(2010), to: date(2011)),
            entry("Bachelor of Science, Mathematics", "Northern Hills University", "Sheffield, UK", from: date(2007), to: date(2010), extra: "First class honours", bullets: [
                "Dissertation on mastery learning in lower secondary mathematics."])
        ])
        s[.skills] = groupSection(.skills, [
            ("Teaching", ["Curriculum planning", "Differentiated instruction", "Assessment design", "Behaviour management"]),
            ("Leadership", ["Department management", "Staff coaching", "Data-led intervention"]),
            ("Tools", ["Learning platform", "Spreadsheet tracking", "Interactive whiteboards"]),
            ("Pastoral", ["Form tutor", "Safeguarding", "Parent communication"])
        ])
        s[.certifications] = entrySection(.certifications, [
            entry("Qualified Teacher Status", "National Teaching Council", from: date(2011)),
            entry("Mathematics Specialist Teacher Award", "Mathematics Teaching Network", from: date(2016)),
            entry("Safeguarding Lead Training", "Leeds Schools Partnership", from: date(2022))
        ])
        s[.awards] = entrySection(.awards, [
            entry("Teaching Excellence Award", "Ashgrove Academy", from: date(2021)),
            entry("Coach of the Winning Team", "Regional Mathematics Challenge", from: date(2018)),
            entry("Outstanding Mentor", "Leeds Teaching Alliance", from: date(2022))
        ])
        s[.languages] = groupSection(.languages, [("", ["English, native", "French, intermediate"])])
        return Persona(personal: personal, sections: s)
    }

    // MARK: Personas, technical and creative

    private static func softwareEngineer() -> Persona {
        let personal = contact(
            name: "Samuel Okonkwo", title: "Senior Software Engineer",
            email: "samuel.okonkwo@example.com", phone: "+1 416 555 0194",
            city: "Toronto", country: "Canada", website: "samuelokonkwo.example")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Backend software engineer with eight years building payment and inventory systems in Go and TypeScript. Likes small services with clear owners, good dashboards and boring deploys. Has led projects of up to six engineers. Writes a short design note before any large change and keeps runbooks current.")
        s[.experience] = entrySection(.experience, [
            entry("Senior Software Engineer", "Tillmark Payments", "Toronto, ON", from: date(2022, 1), current: true, detail: "Part of a payments platform team of 14. The services handle card, bank transfer and wallet payments for 3,000 merchants.", bullets: [
                "Own the ledger service that records 1.2 million transactions a day, written in Go on PostgreSQL.",
                "Cut p99 latency from 480 ms to 140 ms by batching writes and adding two read replicas.",
                "Moved 40 services to container deployments with automated rollbacks; failed deploys fell by 70 percent.",
                "Mentor four engineers and run the weekly design review.",
                "Led a six-engineer project to add multi-currency settlement, launched to 300 merchants in five months.",
                "Wrote the incident review process; repeat incidents fell from 9 to 2 per quarter."]),
            entry("Software Engineer", "Quillwork Logistics", "Toronto, ON", from: date(2019, 3), to: date(2021, 12), detail: "Backend engineer on the shipping platform used by 400 shippers.", bullets: [
                "Built the carrier rate API that quotes 90 routes in under 300 ms.",
                "Replaced a nightly batch job with an event queue, reducing stale inventory counts from hours to seconds.",
                "Added tracing and alerts that cut mean time to recovery from 55 to 18 minutes.",
                "Wrote the migration plan for moving 3 TB of order history with no downtime.",
                "Reduced cloud costs by 27 percent by resizing databases and removing unused queues.",
                "Wrote integration tests against recorded carrier responses that caught 40 regressions before release."]),
            entry("Software Engineer", "Brightpath Studio", "Toronto, ON", from: date(2017, 6), to: date(2019, 2), bullets: [
                "Delivered web apps for 14 clients using TypeScript, React and Node.",
                "Built a booking tool for a dental group that now handles 2,000 appointments a month.",
                "Introduced code review and automated tests; reported bugs fell by 35 percent.",
                "Set up automated deployments that cut release time from half a day to 20 minutes."]),
            entry("Junior Developer", "Arbor Local Media", "Toronto, ON", from: date(2015, 9), to: date(2017, 5), bullets: [
                "Maintained the content site and ad scheduling tools for six local newspapers.",
                "Rewrote the image pipeline, cutting page weight by 40 percent.",
                "Fixed about 15 reader-reported bugs a month and answered support questions from editors."])
        ])
        s[.projects] = entrySection(.projects, [
            entry("Tallybook", "Open-source double-entry ledger library for Go", from: date(2023), current: true, detail: "Used by 120 repositories; 14 outside contributors.", extra: "tallybook.example/code", bullets: [
                "Designed the API and wrote the test suite, which runs 6,000 property-based cases."]),
            entry("Pocket Pantry", "Personal inventory app", from: date(2021), detail: "A small mobile web app that tracks kitchen stock and expiry dates.", bullets: [
                "Built with TypeScript and a local-first sync model; 800 monthly users."]),
            entry("Release Notes Generator", "Open-source command line tool", from: date(2020), detail: "Builds release notes from commit messages and issue labels.", bullets: [
                "Adopted by 60 teams, with around 2,000 downloads a month."])
        ])
        s[.skills] = groupSection(.skills, [
            ("Languages", ["Go", "TypeScript", "Python", "SQL"]),
            ("Backend", ["PostgreSQL", "Redis", "gRPC", "REST design", "Event queues"]),
            ("Infrastructure", ["Docker", "Kubernetes", "Terraform", "CI pipelines", "Observability"]),
            ("Practices", ["Design reviews", "Pair programming", "Incident response", "Technical writing"])
        ])
        s[.education] = entrySection(.education, [
            entry("Bachelor of Science, Computer Science", "Lakehead Valley University", "Thunder Bay, ON", from: date(2011), to: date(2015), bullets: [
                "Teaching assistant for data structures; ran weekly lab sessions for 40 students."])
        ])
        s[.certifications] = entrySection(.certifications, [
            entry("Cloud Architect Associate", "Cloud Skills Board", from: date(2021)),
            entry("Secure Coding Practitioner", "Application Security Board", from: date(2022))
        ])
        return Persona(personal: personal, sections: s)
    }

    private static func uxDesigner() -> Persona {
        let personal = contact(
            name: "Noor Haddad", title: "Senior UX Designer",
            email: "noor.haddad@example.com", phone: "+1 503 555 0165",
            city: "Portland", country: "United States", portfolio: "noorhaddad.example")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "UX designer with nine years in healthcare and consumer apps. Starts with research, prototypes quickly and tests with real users before anything is built. Maintains a design system used by five product teams and is comfortable presenting design decisions to clinicians, engineers and executives.")
        s[.experience] = entrySection(.experience, [
            entry("Senior UX Designer", "Plover Health", "Portland, OR", from: date(2021, 5), current: true, detail: "Leads design for patient booking, messaging and records on web and mobile, with two product managers and eight engineers.", bullets: [
                "Redesigned appointment booking; completion rose from 62 to 81 percent across 400,000 monthly visits.",
                "Ran usability sessions with 60 patients and clinic staff each year and turned findings into a ranked backlog.",
                "Built a design system of 140 components used by five teams, with accessibility checks built in.",
                "Coach two junior designers and lead the weekly critique.",
                "Present research findings to clinic directors each quarter; two roadmap priorities changed as a result."]),
            entry("UX Designer", "Marlowe Apps", "Portland, OR", from: date(2018, 2), to: date(2021, 4), detail: "Designed features for a recipe and meal planning app with 300,000 users.", bullets: [
                "Shipped a mobile onboarding flow that reduced drop-off by 24 percent.",
                "Designed a recipe planning feature adopted by 30 percent of active users in its first month.",
                "Introduced prototype testing before development; rework requests fell by a third.",
                "Built a library of 60 components that halved handoff questions from engineers."]),
            entry("Visual Designer", "Corner Press Studio", "Portland, OR", from: date(2015, 6), to: date(2018, 1), bullets: [
                "Designed identities, packaging and websites for 25 small business clients.",
                "Produced print and screen layouts for two local magazines.",
                "Led brand refreshes for three restaurants and a bookstore."]),
            entry("Design Intern", "Corner Press Studio", "Portland, OR", from: date(2014, 6), to: date(2014, 8), bullets: [
                "Prepared print files and mockups for six client projects.",
                "Redrew a client logo as a vector set that is still in use."])
        ])
        s[.education] = entrySection(.education, [
            entry("Bachelor of Fine Arts, Graphic Design", "Pacific Arts College", "Portland, OR", from: date(2011), to: date(2015), bullets: [
                "Senior project: a wayfinding system for a campus arts building, shown in the graduation exhibition."])
        ])
        s[.projects] = entrySection(.projects, [
            entry("Appointment Booking Redesign", "Plover Health", from: date(2022), detail: "A three-step booking flow with clear availability and reminders.", bullets: [
                "Cut support calls about booking by 28 percent in the first quarter."]),
            entry("Design System 2.0", "Plover Health", from: date(2023), detail: "Tokens, components and writing guidelines shared by web and mobile.", bullets: [
                "Reduced new screen build time from 3 days to 1 on average."]),
            entry("Riverside Library Wayfinding", "Volunteer project", from: date(2020), detail: "Signs and a simple map app for a three-floor public library.")
        ])
        s[.skills] = groupSection(.skills, [
            ("Design", ["Interaction design", "Prototyping", "Usability testing", "Design systems", "Accessibility"]),
            ("Craft", ["Typography", "Layout", "Illustration", "Motion basics"]),
            ("Working with engineers", ["HTML and CSS basics", "Design handoff", "Component specs"])
        ])
        s[.awards] = entrySection(.awards, [
            entry("Accessibility Champion", "Plover Health", from: date(2023)),
            entry("Silver, Interface Design", "Regional Interface Awards", from: date(2020)),
            entry("Design Mentor of the Year", "Pacific Arts College Alumni", from: date(2024))
        ])
        s[.languages] = groupSection(.languages, [("", ["Arabic, native", "English, fluent", "Dutch, beginner"])])
        return Persona(personal: personal, sections: s)
    }

    private static func itAdministrator() -> Persona {
        let personal = contact(
            name: "Ravi Kulkarni", title: "Senior Systems Administrator",
            email: "ravi.kulkarni@example.com", phone: "+1 404 555 0112",
            city: "Atlanta", country: "United States")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Systems administrator with 15 years in IT support and infrastructure. Looks after about 450 endpoints and 60 servers for an insurance company, with a focus on patching, backups and clear documentation. Calm during outages and careful about change records. Writes runbooks and checks backups every week, because a recovery plan only counts once it has been tested.")
        s[.experience] = entrySection(.experience, [
            entry("Senior Systems Administrator", "Corliss Mutual Insurance", "Atlanta, GA", from: date(2020, 8), current: true, detail: "Part of a three-person infrastructure team. Supports 310 employees, six branch offices and a recovery site.", bullets: [
                "Manage 450 endpoints and 60 virtual and physical servers across two offices and a recovery site.",
                "Cut the patch backlog from 31 days to 9 with a monthly maintenance window and a test group.",
                "Rebuilt the backup system and passed a full recovery test: 14 critical systems restored in 5 hours.",
                "Moved identity management to single sign-on for 38 applications, removing about 120 shared logins.",
                "Keep written runbooks for 22 recurring tasks so any of three admins can cover a shift.",
                "Led the move of 280 mailboxes to a hosted mail service over two weekends with no lost mail."]),
            entry("Systems Administrator", "Pinecrest School District", "Marietta, GA", from: date(2016, 4), to: date(2020, 7), detail: "Sole systems administrator for the district office and the technology lead for 11 schools.", bullets: [
                "Supported 11 schools, 6,200 student devices and 900 staff accounts with a team of four.",
                "Deployed a wireless upgrade to 11 campuses over two summers on budget.",
                "Reduced average ticket time from 3 days to 1.5 with a shared knowledge base.",
                "Wrote the device checkout process that cut lost laptops by 40 percent.",
                "Managed a 600,000 dollar yearly technology budget and three vendor contracts.",
                "Replaced aging servers with a three-host virtual cluster, halving server count and power use."]),
            entry("IT Support Specialist", "Larkin & Webb Associates", "Atlanta, GA", from: date(2013, 6), to: date(2016, 3), bullets: [
                "Handled about 60 tickets a week for a 140-person accounting and legal firm.",
                "Set up remote access and two-step sign-in for all staff in under a month.",
                "Wrote the new-hire setup checklist, reducing first-day setup from three hours to 45 minutes."]),
            entry("Help Desk Technician", "Metro Care Clinics", "Atlanta, GA", from: date(2011, 6), to: date(2013, 5), bullets: [
                "Answered phone and walk-up requests for 9 clinics.",
                "Imaged and deployed 220 workstations.",
                "Kept an asset list of 600 devices that passed two internal audits."])
        ])
        s[.certifications] = entrySection(.certifications, [
            entry("Network Administrator Certificate", "Network Skills Association", from: date(2015)),
            entry("Security Practitioner", "Information Security Training Board", from: date(2019)),
            entry("Cloud Fundamentals", "Cloud Skills Board", from: date(2021)),
            entry("Virtualization Administrator", "Systems Training Board", from: date(2018))
        ])
        s[.skills] = groupSection(.skills, [
            ("Systems", ["Windows Server", "Linux", "Virtualization", "Backup and recovery"]),
            ("Networking", ["Firewalls", "VPN", "VLAN design", "DNS and DHCP"]),
            ("Security and tools", ["Patch management", "Identity and access", "Endpoint management", "Ticketing and monitoring"]),
            ("Support", ["Ticket triage", "User training", "Vendor coordination", "Asset tracking"])
        ])
        s[.education] = entrySection(.education, [
            entry("Bachelor of Science, Information Technology", "Southern Online University", "Atlanta, GA", from: date(2014), to: date(2018), extra: "Completed part time while working", bullets: [
                "Capstone: a wireless coverage plan for a three-floor office, carried out by the facilities team."]),
            entry("Associate of Applied Science, Network Technology", "Peachtree Technical College", "Atlanta, GA", from: date(2009), to: date(2011))
        ])
        return Persona(personal: personal, sections: s)
    }

    private static func dataAnalyst() -> Persona {
        let personal = contact(
            name: "Sofia Marchetti", title: "Data Analyst",
            email: "sofia.marchetti@example.com", phone: "+1 617 555 0177",
            city: "Boston", country: "United States", portfolio: "sofiamarchetti.example")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Data analyst with four years in retail analytics. Builds weekly sales and staffing reports for 120 stores, writes SQL against a warehouse of 80 million rows and explains the results to store and finance teams in plain language. Documents every query so that a colleague can rerun it a year later.")
        s[.experience] = entrySection(.experience, [
            entry("Data Analyst", "Tidewater Retail Group", "Boston, MA", from: date(2022, 7), current: true, detail: "Part of a six-person analytics team supporting merchandising, store operations and finance.", bullets: [
                "Built weekly sales dashboards for 120 stores, used by 45 managers every Monday.",
                "Cut forecast error for staffing from 14 to 9 percent by adding weather and local events to the model.",
                "Automated a 6-hour spreadsheet process into a 15-minute scheduled SQL job.",
                "Presented a price test across 30 stores that led to a chain-wide change worth about 900,000 dollars a year.",
                "Documented 25 metric definitions so stores, finance and merchandising use the same numbers."]),
            entry("Junior Analyst", "CityPulse Research", "Boston, MA", from: date(2020, 9), to: date(2022, 6), bullets: [
                "Cleaned and analyzed survey data from 25,000 respondents for municipal clients.",
                "Wrote summary reports with charts that were used in three city budget hearings.",
                "Introduced a review checklist that removed duplicate and incomplete responses before analysis.",
                "Built a reusable survey weighting script that the team now uses on every project."]),
            entry("Research Assistant", "Harborview University, Department of Statistics", "Boston, MA", from: date(2018, 9), to: date(2020, 5), bullets: [
                "Ran regression and clustering analyses for a study of commuter behavior.",
                "Co-authored a conference poster on survey weighting."]),
            entry("Data Intern", "Harbor City Transit", "Boston, MA", from: date(2019, 6), to: date(2019, 8), bullets: [
                "Cleaned and merged six public data sets with about 2 million records.",
                "Built a weekly ridership chart for the planning team."])
        ])
        s[.projects] = entrySection(.projects, [
            entry("Store Staffing Forecast", "Tidewater Retail Group", from: date(2023), detail: "Hourly staffing demand model for 120 stores.", bullets: [
                "Reduced understaffed hours by 21 percent in the first quarter."]),
            entry("Price Change Impact Study", "Tidewater Retail Group", from: date(2024), detail: "Matched-store test of a 4 percent price change on 60 products."),
            entry("Transit Delay Dashboard", "Personal project", from: date(2021), detail: "An open dashboard of bus delays built from public data.", bullets: [
                "Two local reporters check it each week."])
        ])
        s[.education] = entrySection(.education, [
            entry("Bachelor of Science, Statistics", "Harborview University", "Boston, MA", from: date(2016), to: date(2020), extra: "Minor in Economics", bullets: [
                "Honors thesis on commuter route choice, based on 800 survey responses."])
        ])
        s[.skills] = groupSection(.skills, [
            ("Analysis", ["SQL", "Python", "Statistical testing", "Forecasting", "Cohort analysis"]),
            ("Reporting", ["Dashboards", "Data storytelling", "Spreadsheet models"]),
            ("Working practices", ["Version control", "Code review", "Documentation"]),
            ("Domain", ["Retail merchandising", "Store operations", "Pricing analysis"])
        ])
        s[.certifications] = entrySection(.certifications, [
            entry("Data Analytics Professional Certificate", "Analytics Learning Board", from: date(2021)),
            entry("SQL for Analysts", "Analytics Learning Board", from: date(2022))
        ])
        s[.languages] = groupSection(.languages, [("", ["English, fluent", "Italian, native"])])
        return Persona(personal: personal, sections: s)
    }

    // MARK: Personas, academic and early career

    private static func researcher() -> Persona {
        let personal = contact(
            name: "Hannah Lindgren", title: "Postdoctoral Researcher, Marine Ecology",
            email: "hannah.lindgren@example.com", phone: "+47 555 01 28",
            city: "Bergen", country: "Norway", website: "hannahlindgren.example")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Marine ecologist studying how kelp forests recover after marine heatwaves. Eleven publications, three funded grants and four years of teaching field courses. Combines diving surveys with long-term sensor data and mixed-effects models, and supervises two doctoral students. Committed to open data and to explaining coastal science to people outside the field.")
        s[.experience] = entrySection(.experience, [
            entry("Postdoctoral Researcher", "Coastal Ecosystems Lab, University of Northhaven", "Bergen, Norway", from: date(2022, 9), current: true, detail: "Funded by a national research council. The lab has six staff and students.", bullets: [
                "Lead a four-year field study of kelp recovery at 14 sites along 600 km of coastline.",
                "Supervise two doctoral students and three technicians; manage a 420,000 dollar annual budget.",
                "Co-wrote a 1.1 million dollar research council grant, funded on first submission.",
                "Teach the second-year course on marine sampling methods to 60 students.",
                "Present results at two international conferences each year and at local coastal community meetings.",
                "Publish all field data openly in a public repository with a plain-language guide."]),
            entry("Doctoral Researcher", "University of Northhaven", "Bergen, Norway", from: date(2018, 9), to: date(2022, 8), detail: "Thesis on loss and recovery of canopy kelp after marine heatwaves, with four published chapters.", bullets: [
                "Completed 310 research dives and 4 field seasons for a thesis on kelp loss and recovery.",
                "Built a sensor network of 22 temperature loggers that now feeds a public data portal.",
                "Taught practicals for 120 undergraduates across three courses.",
                "Trained 18 junior researchers in diving safety and survey protocols."]),
            entry("Course Instructor, Marine Biology Field School", "Fjordland Marine Station", "Askvoll, Norway", from: date(2019, 6), to: date(2021, 8), bullets: [
                "Taught a two-week summer course in species identification and survey design to 24 students each year."]),
            entry("Research Assistant", "Marine Survey Institute", "Tromso, Norway", from: date(2016, 6), to: date(2018, 8), bullets: [
                "Collected and processed water samples for a seven-site monitoring program.",
                "Maintained the lab database of 18,000 records.",
                "Co-authored a monitoring report that the county used to set two new protected areas."])
        ])
        s[.education] = entrySection(.education, [
            entry("PhD, Marine Ecology", "University of Northhaven", "Bergen, Norway", from: date(2018), to: date(2022), extra: "Thesis: Loss and recovery of canopy kelp after marine heatwaves", bullets: [
                "Examined by an international committee and passed without corrections."]),
            entry("MSc, Marine Biology", "Fjordland University", "Alesund, Norway", from: date(2016), to: date(2018), extra: "Distinction"),
            entry("BSc, Biology", "Gothenburg Coastal University", "Gothenburg, Sweden", from: date(2013), to: date(2016))
        ])
        s[.publications] = entrySection(.publications, [
            entry("Recovery of canopy kelp after marine heatwaves: a nine-site comparison", "Journal of Coastal Ecology", from: date(2024), extra: "Lindgren H, Solberg P, Aune K"),
            entry("Temperature thresholds for juvenile kelp survival", "Marine Ecology Letters", from: date(2023), extra: "Lindgren H, Aune K"),
            entry("Low-cost temperature loggers for long-term reef monitoring", "Methods in Ocean Science", from: date(2022), extra: "Lindgren H, Dahl M, Solberg P"),
            entry("Urchin grazing and kelp loss along a coastal gradient", "Journal of Coastal Ecology", from: date(2021), extra: "Dahl M, Lindgren H"),
            entry("Diving surveys and imagery compared for kelp cover", "Estuarine and Coastal Science Review", from: date(2020), extra: "Lindgren H"),
            entry("Seasonal growth of Laminaria in a warming fjord", "Nordic Marine Biology Reports", from: date(2019), extra: "Lindgren H, Aune K"),
            entry("Spatial patterns of kelp loss along 600 km of coastline", "Journal of Coastal Ecology", from: date(2025), extra: "Lindgren H, Solberg P, Dahl M, Aune K"),
            entry("Heat tolerance of kelp gametophytes from three populations", "Marine Ecology Letters", from: date(2025), extra: "Aune K, Lindgren H"),
            entry("A field guide to temperature loggers for reef monitoring", "Fjordland Marine Station Report Series", from: date(2021), extra: "Lindgren H, Dahl M")
        ])
        s[.awards] = entrySection(.awards, [
            entry("Early Career Research Prize", "Nordic Marine Science Society", from: date(2024)),
            entry("Doctoral Dissertation Award", "University of Northhaven", from: date(2022)),
            entry("Travel Grant", "International Kelp Forum", from: date(2023)),
            entry("Outstanding Poster", "Coastal Science Symposium", from: date(2021))
        ])
        s[.memberships] = entrySection(.memberships, [
            entry("Member", "Nordic Marine Science Society", from: date(2017), current: true),
            entry("Steering Committee", "Early Career Ecologists Network", from: date(2023), current: true),
            entry("Peer Reviewer", "Three coastal science journals", from: date(2021), current: true)
        ])
        s[.skills] = groupSection(.skills, [
            ("Field methods", ["Scientific diving", "Transect sampling", "Water sampling", "Sensor deployment"]),
            ("Analysis", ["R", "Mixed-effects models", "Time series", "Geospatial mapping"]),
            ("Teaching and supervision", ["Practical teaching", "Thesis supervision", "Grant writing"]),
            ("Outreach and service", ["Public talks", "Peer review", "Open data practice"])
        ])
        s[.languages] = groupSection(.languages, [("", ["Swedish, native", "English, fluent", "Norwegian, working proficiency"])])
        return Persona(personal: personal, sections: s)
    }

    private static func graduate() -> Persona {
        let personal = contact(
            name: "Jordan Reyes", title: "Business Analytics Graduate",
            email: "jordan.reyes@example.com", phone: "+1 480 555 0153",
            city: "Phoenix", country: "United States")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Recent business analytics graduate with a summer internship and a student consulting project. Looking for an entry-level analyst role. Comfortable with spreadsheets and SQL basics, and good at writing short, clear summaries for people who do not work with data.")
        s[.experience] = entrySection(.experience, [
            entry("Business Analytics Intern", "Saguaro Credit Union", "Phoenix, AZ", from: date(2025, 6), to: date(2025, 8), detail: "Ten-week internship with the retail banking analytics team.", bullets: [
                "Cleaned 18 months of membership data (62,000 rows) and built a dashboard now used by branch managers.",
                "Found that 11 percent of new accounts were never funded, which led to a welcome call pilot at two branches.",
                "Presented findings to the head of retail banking in a 10-minute briefing.",
                "Wrote a one-page guide to the dashboard filters for branch managers."]),
            entry("Student Consultant", "Desert State University Business Clinic", "Tempe, AZ", from: date(2024, 9), to: date(2025, 5), detail: "Student team advising local businesses for a full academic year.", bullets: [
                "Interviewed the owner and six customers to find out why weekday sales were slow.",
                "Worked in a team of four to advise a local bakery on weekday sales.",
                "Recommended a weekday pickup promotion that raised weekday sales by 12 percent in a two-month trial."]),
            entry("Sales Associate (part time)", "Coppervale Outfitters", "Tempe, AZ", from: date(2022, 5), to: date(2024, 8), bullets: [
                "Served about 60 customers per shift and handled cash and card payments.",
                "Trained six new seasonal staff on the point-of-sale system.",
                "Received the store's customer service recognition twice."]),
            entry("Peer Tutor, Statistics", "Desert State University Learning Center", "Tempe, AZ", from: date(2023, 8), to: date(2025, 5), bullets: [
                "Tutored 15 students a semester in introductory statistics.",
                "Wrote practice problems that the course instructor added to the study guide."])
        ])
        s[.education] = entrySection(.education, [
            entry("Bachelor of Business Administration, Business Analytics", "Desert State University", "Tempe, AZ", from: date(2021), to: date(2025), extra: "GPA 3.7 of 4.0. Coursework: statistics, databases, operations, marketing research", bullets: [
                "Member of the Business Analytics Club; organized two data workshops for 60 students."])
        ])
        s[.projects] = entrySection(.projects, [
            entry("Customer Churn Study", "Capstone project", from: date(2025), detail: "Analyzed 24,000 subscription records and identified three early signs of cancellation.", bullets: [
                "Wrote the final report and a one-page summary for the client."]),
            entry("Campus Cafe Demand Forecast", "Course project", from: date(2024), detail: "Forecast daily coffee demand from class schedules with a simple regression.")
        ])
        s[.skills] = groupSection(.skills, [
            ("Analysis", ["Spreadsheets", "SQL basics", "Charts and dashboards", "Survey design"]),
            ("Communication", ["Report writing", "Presenting", "Team projects"]),
            ("Tools", ["Presentation software", "Statistical software", "Version control basics"])
        ])
        s[.awards] = entrySection(.awards, [
            entry("Dean's List, six semesters", "Desert State University", from: date(2022), to: date(2025)),
            entry("Second place, Business Case Competition", "Desert State University", from: date(2024))
        ])
        s[.volunteer] = entrySection(.volunteer, [
            entry("Volunteer Tutor", "Westside Library", "Phoenix, AZ", from: date(2023), to: date(2025), detail: "Helped middle school students with math homework twice a week.")
        ])
        return Persona(personal: personal, sections: s)
    }

    private static func student() -> Persona {
        let personal = contact(
            name: "Amara Singh", title: "Environmental Science Student",
            email: "amara.singh@example.com", phone: "+1 608 555 0129",
            city: "Madison", country: "United States")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Second-year environmental science student looking for a summer internship in water quality or conservation. Has field sampling experience, works well in small teams and keeps accurate records. Volunteers weekly with a local river cleanup group.")
        s[.education] = entrySection(.education, [
            entry("Bachelor of Science, Environmental Science (expected 2028)", "Northfield State University", "Madison, WI", from: date(2024), to: date(2028), extra: "GPA 3.8 of 4.0. Coursework: general chemistry, ecology, statistics, introductory GIS", bullets: [
                "Member of the Environmental Science Student Association and its fundraising committee."])
        ])
        s[.internships] = entrySection(.internships, [
            entry("Summer Intern", "Clearwater Watershed Council", "Madison, WI", from: date(2025, 6), to: date(2025, 8), detail: "Ten-week summer internship supporting field staff and the education coordinator.", bullets: [
                "Wrote a plain-language summary of the year's water results for the council newsletter.",
                "Collected and logged water samples at 12 sites along two streams each week.",
                "Entered 400 field records into the council database with no errors found in review.",
                "Helped run a stream cleanup day with 45 volunteers."])
        ])
        s[.experience] = entrySection(.experience, [
            entry("Barista (part time)", "Lakeside Coffee", "Madison, WI", from: date(2024, 9), current: true, bullets: [
                "Serve about 120 customers in a weekend shift and handle opening and closing duties.",
                "Suggested a reusable cup discount that now accounts for 15 percent of drinks sold.",
                "Open the shop alone twice a week and balance the cash drawer at close."]),
            entry("Tutor", "Eastgate High School Peer Program", "Madison, WI", from: date(2022, 9), to: date(2024, 6), bullets: [
                "Tutored younger students in biology and algebra for two hours each week.",
                "Prepared short practice quizzes that the teacher adopted for the whole class."])
        ])
        s[.projects] = entrySection(.projects, [
            entry("Campus Compost Audit", "Environmental science course", from: date(2025), detail: "Weighed and sorted waste from four dining halls for two weeks and presented ways to reduce contamination.", bullets: [
                "Findings were shared with the campus sustainability office."]),
            entry("Rain Garden Plan", "Neighborhood volunteer project", from: date(2024), detail: "Helped design a small rain garden for a community center.", bullets: [
                "Measured the drainage area and estimated the garden will absorb about 8,000 liters in a heavy storm."])
        ])
        s[.skills] = groupSection(.skills, [
            ("Lab and field", ["Water sampling", "Data entry", "Basic GIS"]),
            ("Computer", ["Spreadsheets", "Presentations", "Basic Python"]),
            ("Personal", ["Reliable", "Careful with records", "Team player"])
        ])
        s[.languages] = groupSection(.languages, [("", ["English, native", "Hindi, conversational"])])
        s[.interests] = textSection(.interests, "Trail running, community gardening, bird watching and baking bread.")
        return Persona(personal: personal, sections: s)
    }

    private static func firstJobSeeker() -> Persona {
        let personal = contact(
            name: "Diego Park", title: "Recent High School Graduate",
            email: "diego.park@example.com", phone: "+1 916 555 0108",
            city: "Sacramento", country: "United States")
        var s: [SectionKind: ResumeSection] = [:]
        s[.summary] = textSection(.summary, "Recent high school graduate looking for a part-time or full-time role in food service, retail or warehouse work. Shows up on time, learns quickly and is used to working in a busy kitchen. Happy to work weekends, evenings and holidays.")
        s[.experience] = entrySection(.experience, [
            entry("Kitchen Helper (part time)", "Parkside Pizza", "Sacramento, CA", from: date(2024, 6), current: true, detail: "Busy family restaurant with 14 staff, open Friday to Sunday.", bullets: [
                "Learned every station and can work the prep, dish and counter areas.",
                "Prepare toppings and dough for about 150 pizzas on a weekend night.",
                "Follow food safety rules for storage, cleaning and temperature logs.",
                "Cover extra shifts during holidays and was asked to train two new hires."]),
            entry("Lawn and Yard Work", "Self-employed", "Sacramento, CA", from: date(2022, 5), to: date(2024, 5), bullets: [
                "Looked after yards for eight neighbors on a weekly schedule.",
                "Kept a simple log of jobs, hours and payments.",
                "Earned repeat bookings from five of eight clients."])
        ])
        s[.education] = entrySection(.education, [
            entry("High School Diploma", "Eastgate High School", "Sacramento, CA", from: date(2020), to: date(2024), extra: "GPA 3.4 of 4.0. Member of the soccer team for four years", bullets: [
                "Completed a two-semester course in food preparation and kitchen safety.",
                "Captain of the junior varsity soccer team in the final year."])
        ])
        s[.volunteer] = entrySection(.volunteer, [
            entry("Volunteer", "Capital Region Food Bank", "Sacramento, CA", from: date(2022), current: true, detail: "Sorts and packs food for about 3 hours twice a month; helped pack over 2,000 boxes in one holiday drive.", bullets: [
                "Helped train 10 new volunteers on packing and safe lifting."])
        ])
        s[.courses] = entrySection(.courses, [
            entry("Food Handler Certificate", "County Health Department course", from: date(2024)),
            entry("Basic First Aid and CPR", "Community Safety Training", from: date(2025))
        ])
        s[.skills] = groupSection(.skills, [
            ("Work habits", ["On time", "Teamwork", "Follows instructions", "Learns quickly"]),
            ("Practical", ["Food safety", "Cash handling", "Point-of-sale basics", "Spreadsheets"]),
            ("Equipment", ["Commercial mixers and ovens", "Pallet jack", "Phone and tablet apps"])
        ])
        s[.languages] = groupSection(.languages, [("", ["English, native", "Korean, conversational"])])
        return Persona(personal: personal, sections: s)
    }
}
