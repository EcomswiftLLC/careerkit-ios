import Foundation

struct CoverLetter: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var templateID: String
    var createdAt = Date()
    var updatedAt = Date()
    var pageSize: PageSize = .a4
    var linkedResumeID: UUID?

    // Sender block (usually copied from the linked resume).
    var senderName = ""
    var senderTitle = ""
    var senderEmail = ""
    var senderPhone = ""
    var senderLocation = ""

    // Recipient block.
    var recipientName = ""
    var recipientTitle = ""
    var companyName = ""
    var companyAddress = ""
    var jobTitle = ""
    /// The pasted job description, kept for reference and never uploaded.
    var jobDescription = ""

    var date = Date()
    var greeting = ""
    var introduction = ""
    var experienceParagraph = ""
    var interestParagraph = ""
    var closing = ""
    var signOff = String(localized: "Sincerely,", comment: "Default sign-off of a cover letter.")

    var style = StyleOverrides()
    var schemaVersion = 1

    var bodyParagraphs: [String] {
        [introduction, experienceParagraph, interestParagraph, closing]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var effectiveGreeting: String {
        if !greeting.isEmpty { return greeting }
        if !recipientName.isEmpty {
            let name: String = recipientName
            return String(localized: "Dear \(name),", comment: "Cover letter greeting with the recipient's name.")
        }
        return String(localized: "Dear Hiring Manager,", comment: "Cover letter greeting when no name is known.")
    }
}
