import SwiftUI

/// Plain-English names and tiny page drawings for every structural choice in the style panel.
/// The drawings use the resume's current accent so each tile is a live sample.
enum EdStyleNames {
    static func header(_ style: HeaderStyle) -> String {
        switch style {
        case .leftAligned: return String(localized: "Left")
        case .centered: return String(localized: "Centered")
        case .splitContact: return String(localized: "Contact right")
        case .ruledMonogram: return String(localized: "Underlined")
        case .banner: return String(localized: "Color band")
        case .sidebarCard: return String(localized: "In sidebar")
        case .monogramBadge: return String(localized: "Initials")
        case .accentRuleLeft: return String(localized: "Side bar")
        case .centeredAccent: return String(localized: "Centered color")
        case .doubleRule: return String(localized: "Double rule")
        case .rightAligned: return String(localized: "Right")
        case .tintedCard: return String(localized: "Panel")
        case .bannerCentered: return String(localized: "Centered band")
        case .initialLetter: return String(localized: "Big initial")
        case .smallCapsCentered: return String(localized: "Spaced capitals")
        }
    }

    static func heading(_ style: SectionHeadingStyle) -> String {
        switch style {
        case .uppercaseRule: return String(localized: "Line under")
        case .smallCapsAccent: return String(localized: "Small caps")
        case .accentBar: return String(localized: "Bar above")
        case .boxedLabel: return String(localized: "Filled label")
        case .plainBold: return String(localized: "Bold only")
        case .sideLabel: return String(localized: "In margin")
        case .dottedRule: return String(localized: "Dotted line")
        case .underlineAccent: return String(localized: "Short underline")
        case .centeredRule: return String(localized: "Centered")
        case .leftBorder: return String(localized: "Bar beside")
        case .tintedBand: return String(localized: "Tinted band")
        case .fullBar: return String(localized: "Solid bar")
        case .ruleAbove: return String(localized: "Rule above")
        }
    }

    static func entry(_ layout: EntryLayout) -> String {
        switch layout {
        case .dateRight: return String(localized: "Dates right")
        case .dateBelow: return String(localized: "Dates below")
        case .dateGutter: return String(localized: "Dates in margin")
        case .stacked: return String(localized: "Stacked")
        case .timeline: return String(localized: "Timeline")
        }
    }

    static func bullet(_ style: BulletStyle) -> String {
        switch style {
        case .disc: return String(localized: "Dot")
        case .dash: return String(localized: "Dash")
        case .square: return String(localized: "Square")
        case .chevron: return String(localized: "Arrow")
        case .none: return String(localized: "None")
        }
    }

    static func skills(_ style: SkillStyle) -> String {
        switch style {
        case .commaList: return String(localized: "Commas")
        case .pipeList: return String(localized: "Dividers")
        case .groupedLines: return String(localized: "By group")
        case .bulletColumns: return String(localized: "Two columns")
        case .pills: return String(localized: "Pills")
        }
    }

    static func photoSize(_ size: PhotoSizeOption) -> String {
        switch size {
        case .small: return String(localized: "Small")
        case .medium: return String(localized: "Medium")
        case .large: return String(localized: "Large")
        }
    }

    static func photoBorder(_ border: PhotoBorderOption) -> String {
        switch border {
        case .none: return String(localized: "None")
        case .ring: return String(localized: "Thin ring")
        }
    }

    static func photoShape(_ shape: PhotoShape) -> String {
        switch shape {
        case .circle: return String(localized: "Circle")
        case .rounded: return String(localized: "Rounded")
        case .square: return String(localized: "Square")
        }
    }
}

enum EdSamples {
    private typealias S = EdSampleInk

    // MARK: Header

    @ViewBuilder
    static func header(_ style: HeaderStyle, accent: Color) -> some View {
        switch style {
        case .leftAligned:
            VStack(alignment: .leading, spacing: 3) {
                S.bar(30, 5, S.ink)
                S.bar(20, 2.5, accent)
                S.bar(40, 2)
                Spacer(minLength: 0)
                S.body()
            }
        case .centered:
            VStack(alignment: .center, spacing: 3) {
                S.bar(30, 5, S.ink)
                S.bar(20, 2.5, accent)
                S.bar(40, 2)
                Spacer(minLength: 0)
                S.body()
            }
            .frame(maxWidth: .infinity)
        case .splitContact:
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        S.bar(26, 5, S.ink)
                        S.bar(18, 2.5, accent)
                    }
                    Spacer(minLength: 2)
                    VStack(alignment: .trailing, spacing: 2) {
                        S.bar(14, 2)
                        S.bar(18, 2)
                        S.bar(12, 2)
                    }
                }
                Rectangle().fill(S.line).frame(height: 0.75)
                Spacer(minLength: 0)
                S.body()
            }
        case .ruledMonogram:
            VStack(alignment: .leading, spacing: 3) {
                S.bar(32, 5, S.ink)
                Rectangle().fill(accent).frame(height: 2)
                S.bar(20, 2.5, accent)
                Spacer(minLength: 0)
                S.body()
            }
        case .banner:
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 3) {
                    S.bar(28, 5, Color.white)
                    S.bar(36, 2, Color.white.opacity(0.7))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accent)
                .padding(.horizontal, -7)
                .padding(.top, -7)
                Spacer(minLength: 0)
                S.body()
            }
        case .sidebarCard:
            HStack(alignment: .top, spacing: 5) {
                VStack(alignment: .leading, spacing: 3) {
                    Circle().fill(Color.white.opacity(0.85)).frame(width: 10, height: 10)
                    S.bar(14, 3, Color.white)
                    S.bar(10, 2, Color.white.opacity(0.7))
                }
                .padding(4)
                .frame(width: 24)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(accent)
                .padding(.leading, -7)
                .padding(.vertical, -7)
                VStack(alignment: .leading, spacing: 3) {
                    S.bar(24, 3, S.ink)
                    S.bar(30)
                    S.bar(22)
                }
            }
        case .monogramBadge:
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 4) {
                    Circle().fill(accent).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 2.5) {
                        S.bar(24, 4, S.ink)
                        S.bar(16, 2.5, accent)
                    }
                }
                Spacer(minLength: 0)
                S.body()
            }
        case .accentRuleLeft:
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 4) {
                    Rectangle().fill(accent).frame(width: 2.5, height: 15)
                    VStack(alignment: .leading, spacing: 3) {
                        S.bar(26, 5, S.ink)
                        S.bar(18, 2.5, accent)
                    }
                }
                Spacer(minLength: 0)
                S.body()
            }
        case .centeredAccent:
            VStack(alignment: .center, spacing: 3) {
                S.bar(30, 5, accent)
                S.bar(8, 1, accent)
                S.bar(20, 2.5, S.ink)
                Spacer(minLength: 0)
                S.body()
            }
            .frame(maxWidth: .infinity)
        case .doubleRule:
            VStack(alignment: .leading, spacing: 3) {
                Rectangle().fill(accent).frame(height: 0.75)
                S.bar(30, 5, S.ink)
                S.bar(18, 2.5, accent)
                Rectangle().fill(accent).frame(height: 2)
                Rectangle().fill(accent).frame(height: 0.5)
                Spacer(minLength: 0)
                S.body()
            }
        case .rightAligned:
            VStack(alignment: .trailing, spacing: 3) {
                S.bar(30, 5, S.ink)
                S.bar(10, 1.5, accent)
                S.bar(20, 2.5, accent)
                Spacer(minLength: 0)
                S.body()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .tintedCard:
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        S.bar(22, 4, S.ink)
                        S.bar(14, 2.5, accent)
                    }
                    Spacer(minLength: 2)
                    VStack(alignment: .trailing, spacing: 2) {
                        S.bar(12, 2)
                        S.bar(14, 2)
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 3).fill(accent.opacity(0.10)))
                Spacer(minLength: 0)
                S.body()
            }
        case .bannerCentered:
            VStack(alignment: .center, spacing: 4) {
                VStack(alignment: .center, spacing: 3) {
                    Circle().fill(Color.white.opacity(0.85)).frame(width: 8, height: 8)
                    S.bar(26, 4, Color.white)
                    S.bar(30, 2, Color.white.opacity(0.7))
                }
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(accent)
                .padding(.horizontal, -7)
                .padding(.top, -7)
                Spacer(minLength: 0)
                S.body()
            }
        case .initialLetter:
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 4) {
                    Text(verbatim: "A")
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 2.5) {
                        S.bar(24, 4, S.ink)
                        S.bar(16, 2.5, accent)
                    }
                }
                Spacer(minLength: 0)
                S.body()
            }
        case .smallCapsCentered:
            VStack(alignment: .center, spacing: 3) {
                Rectangle().fill(accent).frame(height: 0.5)
                S.bar(34, 3, S.ink)
                S.bar(18, 2, accent)
                Rectangle().fill(accent).frame(height: 0.5)
                Spacer(minLength: 0)
                S.body()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Section heading

    @ViewBuilder
    static func heading(_ style: SectionHeadingStyle, accent: Color) -> some View {
        switch style {
        case .uppercaseRule:
            VStack(alignment: .leading, spacing: 3) {
                S.bar(26, 3.5, accent)
                Rectangle().fill(S.line).frame(height: 0.75)
                S.body()
            }
        case .smallCapsAccent:
            VStack(alignment: .leading, spacing: 4) {
                S.bar(22, 3.5, accent)
                S.body()
            }
        case .accentBar:
            VStack(alignment: .leading, spacing: 3) {
                S.bar(10, 2.5, accent)
                S.bar(24, 3.5, S.ink)
                S.body()
            }
        case .boxedLabel:
            VStack(alignment: .leading, spacing: 4) {
                S.bar(20, 3, Color.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2.5)
                    .background(RoundedRectangle(cornerRadius: 2).fill(accent))
                S.body()
            }
        case .plainBold:
            VStack(alignment: .leading, spacing: 4) {
                S.bar(24, 4, S.ink)
                S.body()
            }
        case .sideLabel:
            HStack(alignment: .top, spacing: 5) {
                S.bar(12, 3.5, accent)
                S.body(38)
            }
        case .dottedRule:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 3) {
                    S.bar(18, 3.5, accent)
                    EdDottedLine()
                        .stroke(S.line, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.1, 2.6]))
                        .frame(height: 2)
                }
                S.body()
            }
        case .underlineAccent:
            VStack(alignment: .leading, spacing: 3) {
                S.bar(24, 3.5, S.ink)
                S.bar(10, 2, accent)
                S.body()
            }
        case .centeredRule:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Rectangle().fill(S.line).frame(height: 0.75)
                    S.bar(18, 3.5, accent)
                    Rectangle().fill(S.line).frame(height: 0.75)
                }
                S.body()
            }
        case .leftBorder:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 3) {
                    Rectangle().fill(accent).frame(width: 2.5, height: 7)
                    S.bar(22, 3.5, S.ink)
                }
                S.body()
            }
        case .tintedBand:
            VStack(alignment: .leading, spacing: 4) {
                S.bar(20, 3.5, accent)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 2.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(accent.opacity(0.12))
                S.body()
            }
        case .fullBar:
            VStack(alignment: .leading, spacing: 4) {
                S.bar(20, 3.5, Color.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 2.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(accent)
                S.body()
            }
        case .ruleAbove:
            VStack(alignment: .leading, spacing: 3) {
                Rectangle().fill(S.ink).frame(height: 1.5)
                S.bar(24, 3.5, S.ink)
                S.body()
            }
        }
    }

    // MARK: Entry layout

    @ViewBuilder
    static func entry(_ layout: EntryLayout, accent: Color) -> some View {
        switch layout {
        case .dateRight:
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    S.bar(26, 3.5, S.ink)
                    Spacer(minLength: 2)
                    S.bar(12, 2.5, accent)
                }
                S.bar(20, 2.5)
                S.body()
            }
        case .dateBelow:
            VStack(alignment: .leading, spacing: 3) {
                S.bar(26, 3.5, S.ink)
                HStack(spacing: 3) {
                    S.bar(16, 2.5)
                    S.bar(12, 2.5, accent)
                }
                S.body()
            }
        case .dateGutter:
            HStack(alignment: .top, spacing: 5) {
                S.bar(10, 2.5, accent)
                VStack(alignment: .leading, spacing: 3) {
                    S.bar(24, 3.5, S.ink)
                    S.bar(16, 2.5)
                    S.body(36)
                }
            }
        case .stacked:
            VStack(alignment: .leading, spacing: 3) {
                S.bar(26, 3.5, S.ink)
                S.bar(20, 2.5)
                S.bar(14, 2.5, accent)
                S.body(44)
            }
        case .timeline:
            HStack(alignment: .top, spacing: 4) {
                S.bar(8, 2.5, accent)
                VStack(spacing: 0) {
                    Circle().fill(accent).frame(width: 4, height: 4)
                    Rectangle().fill(S.line).frame(width: 0.75)
                }
                .frame(width: 4)
                VStack(alignment: .leading, spacing: 3) {
                    S.bar(22, 3.5, S.ink)
                    S.bar(14, 2.5)
                    S.body(30)
                }
            }
        }
    }

    // MARK: Skills

    @ViewBuilder
    static func skills(_ style: SkillStyle, accent: Color) -> some View {
        let small: Font = .system(size: 8)
        let smallBold: Font = .system(size: 8, weight: .semibold)
        switch style {
        case .commaList:
            Text(verbatim: "Swift, Figma, SQL, Excel")
                .font(small).foregroundStyle(S.ink).lineLimit(2)
        case .pipeList:
            Text(verbatim: "Swift | Figma | SQL")
                .font(small).foregroundStyle(S.ink).lineLimit(2)
        case .groupedLines:
            VStack(alignment: .leading, spacing: 2) {
                (Text("Tools: ").font(smallBold) + Text(verbatim: "Figma, Excel").font(small)).foregroundColor(S.ink)
                (Text("Code: ").font(smallBold) + Text(verbatim: "Swift, SQL").font(small)).foregroundColor(S.ink)
            }
            .lineLimit(1)
        case .bulletColumns:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    (Text("• ").foregroundColor(accent) + Text(verbatim: "Swift").foregroundColor(S.ink)).font(small)
                    (Text("• ").foregroundColor(accent) + Text(verbatim: "SQL").foregroundColor(S.ink)).font(small)
                }
                HStack(spacing: 6) {
                    (Text("• ").foregroundColor(accent) + Text(verbatim: "Figma").foregroundColor(S.ink)).font(small)
                    (Text("• ").foregroundColor(accent) + Text(verbatim: "Excel").foregroundColor(S.ink)).font(small)
                }
            }
        case .pills:
            HStack(spacing: 3) {
                ForEach(["Swift", "SQL", "Figma"], id: \.self) { word in
                    Text(word)
                        .font(small)
                        .foregroundStyle(S.ink)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(accent.opacity(0.14)))
                }
            }
            .lineLimit(1)
        }
    }
}
