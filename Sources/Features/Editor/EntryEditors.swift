import SwiftUI

// MARK: - Month and year

/// Month and year menus with a clear button. Month is optional: "year only" is valid.
struct EdMonthYearField: View {
    let label: String
    @Binding var value: MonthYear?

    private let months = MonthYearHelper.shortMonthNames()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
                .accessibilityHidden(true)
            HStack(spacing: CK.Space.s) {
                Picker("\(label) month", selection: monthBinding) {
                    Text("Month").tag(0)
                    ForEach(1...12, id: \.self) { month in
                        Text(months[month - 1]).tag(month)
                    }
                }
                .pickerStyle(.menu)
                .disabled(value == nil)
                .modifier(PickerChrome())

                Picker("\(label) year", selection: yearBinding) {
                    Text("Year").tag(0)
                    ForEach(MonthYearHelper.years(including: value?.year), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.menu)
                .modifier(PickerChrome())

                if value != nil {
                    Button { value = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CK.Palette.graphite)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Clear \(label)")
                }
            }
        }
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { value?.year ?? 0 },
            set: { year in
                value = MonthYearHelper.make(year: year, month: value?.month)
            }
        )
    }

    private var monthBinding: Binding<Int> {
        Binding(
            get: { value?.month ?? 0 },
            set: { month in
                guard let current = value else { return }
                value = MonthYearHelper.make(year: current.year, month: month == 0 ? nil : month)
            }
        )
    }

    private struct PickerChrome: ViewModifier {
        func body(content: Content) -> some View {
            content
                .tint(CK.Palette.forest)
                .padding(.horizontal, 6)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).fill(CK.Palette.ivory))
                .overlay(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 1))
        }
    }
}

// MARK: - Bullets

struct EdBulletEditor: View {
    @Binding var bullets: [String]
    var showsExamples: Bool
    var onExamples: () -> Void

    @FocusState private var focusedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.s + 2) {
            Text("Achievements and responsibilities")
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
            ForEach(Array(bullets.indices), id: \.self) { index in
                row(index)
            }
            HStack {
                EdTextButton(title: "Add bullet", systemImage: "plus") {
                    bullets.append("")
                    focusedIndex = bullets.count - 1
                }
                Spacer()
                if showsExamples {
                    EdTextButton(title: "Writing examples", systemImage: "text.book.closed", action: onExamples)
                }
            }
        }
    }

    private func row(_ index: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(CK.Font.body)
                .foregroundStyle(CK.Palette.forest)
                .frame(width: 14, height: 36)
                .accessibilityHidden(true)
            TextField("Describe what you did and the result", text: bulletBinding(index), axis: .vertical)
                .font(CK.Font.body)
                .lineLimit(1...6)
                .focused($focusedIndex, equals: index)
                .frame(minHeight: 36)
            EdMoreMenu(label: "Bullet actions") {
                Button("Move up", systemImage: "arrow.up") { move(index, by: -1) }
                    .disabled(index == 0)
                Button("Move down", systemImage: "arrow.down") { move(index, by: 1) }
                    .disabled(index >= bullets.count - 1)
                Button("Delete bullet", systemImage: "trash", role: .destructive) {
                    var copy = bullets
                    if ListEditing.remove(&copy, at: index) != nil { bullets = copy }
                }
            }
        }
        .padding(.leading, 2)
        .overlay(alignment: .bottom) { Rectangle().fill(CK.Palette.hairline).frame(height: 0.5) }
    }

    private func bulletBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { bullets.indices.contains(index) ? bullets[index] : "" },
            set: { if bullets.indices.contains(index) { bullets[index] = $0 } }
        )
    }

    private func move(_ index: Int, by offset: Int) {
        var copy = bullets
        if ListEditing.move(&copy, index: index, by: offset) { bullets = copy }
    }
}

// MARK: - One entry

struct EdEntryCard: View {
    @Binding var entry: ResumeEntry
    let labels: EntryLabels
    let isFirst: Bool
    let isLast: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onMove: (Int) -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var showExamples = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                Rectangle().fill(CK.Palette.hairline).frame(height: 0.5)
                fields.padding(CK.Space.m)
            }
        }
        .background(RoundedRectangle(cornerRadius: CK.Radius.chip + 2, style: .continuous).fill(CK.Palette.ivory))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.chip + 2, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
        .sheet(isPresented: $showExamples) {
            WritingExamplesSheet(mode: .achievements) { example in
                entry.bullets.append(example)
            }
        }
    }

    private var title: String {
        let heading = entry.heading.trimmingCharacters(in: .whitespaces)
        return heading.isEmpty ? "Untitled" : heading
    }

    private var detailLine: String {
        var parts: [String] = []
        if !entry.subheading.isEmpty { parts.append(entry.subheading) }
        let dates = entry.dateRange()
        if !dates.isEmpty { parts.append(dates) }
        return parts.joined(separator: ", ")
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(CK.Font.label)
                            .foregroundStyle(entry.heading.isEmpty ? CK.Palette.graphite : CK.Palette.ink)
                            .lineLimit(1)
                        if !detailLine.isEmpty {
                            Text(detailLine)
                                .font(CK.Font.caption)
                                .foregroundStyle(CK.Palette.graphite)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CK.Palette.graphite)
                        .accessibilityHidden(true)
                }
                .padding(.leading, CK.Space.m)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(detailLine.isEmpty ? title : "\(title), \(detailLine)")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            EdMoreMenu(label: "Entry actions") {
                Button("Move up", systemImage: "arrow.up") { onMove(-1) }.disabled(isFirst)
                Button("Move down", systemImage: "arrow.down") { onMove(1) }.disabled(isLast)
                Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            EdField(label: labels.heading, text: $entry.heading)
            EdField(label: labels.subheading, text: $entry.subheading)
            if labels.showsLocation {
                EdField(label: "Location", text: $entry.location, prompt: "City, country")
            }
            if labels.showsDates {
                EdMonthYearField(label: "Start", value: $entry.start)
                if let toggleText = labels.currentToggle {
                    Toggle(toggleText, isOn: $entry.isCurrent)
                        .font(CK.Font.callout)
                        .tint(CK.Palette.forest)
                        .frame(minHeight: 44)
                }
                if !entry.isCurrent || labels.currentToggle == nil {
                    EdMonthYearField(label: "End", value: $entry.end)
                }
                if !MonthYearHelper.isValidRange(start: entry.start, end: entry.isCurrent ? nil : entry.end) {
                    Label("The end date is before the start date.", systemImage: "exclamationmark.triangle")
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.danger)
                }
            }
            EdTextArea(label: "Description", text: $entry.detail, prompt: "Optional. A short paragraph about the role or project.", minHeight: 80)
            if labels.showsBullets {
                EdBulletEditor(bullets: $entry.bullets, showsExamples: labels.offersExamples) { showExamples = true }
            }
            EdField(label: labels.extra, text: $entry.extra, capitalization: .never)
        }
    }
}

// MARK: - Section of entries

struct EntriesSectionEditor: View {
    @Binding var section: ResumeSection

    @State private var expandedID: UUID?
    @State private var pendingDelete: UUID?

    private var labels: EntryLabels { EntryLabels.labels(for: section.kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            if section.kind == .custom {
                EdField(label: "Section heading", text: $section.title)
            }
            ForEach($section.entries) { $entry in
                let index = section.entries.firstIndex(where: { $0.id == entry.id }) ?? 0
                EdEntryCard(
                    entry: $entry,
                    labels: labels,
                    isFirst: index == 0,
                    isLast: index >= section.entries.count - 1,
                    isExpanded: expandedID == entry.id,
                    onToggle: { expandedID = (expandedID == entry.id) ? nil : entry.id },
                    onMove: { offset in
                        var copy = section.entries
                        if ListEditing.move(&copy, index: index, by: offset) { section.entries = copy }
                    },
                    onDuplicate: {
                        SectionOps.duplicateEntry(in: &section, at: index)
                        if section.entries.indices.contains(index + 1) { expandedID = section.entries[index + 1].id }
                    },
                    onDelete: {
                        if entry.isEmpty { delete(entry.id) } else { pendingDelete = entry.id }
                    }
                )
            }
            EdTextButton(title: labels.addButton, systemImage: "plus") {
                let new = ResumeEntry()
                section.entries.append(new)
                expandedID = new.id
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: deleteBinding, titleVisibility: .visible) {
            Button("Delete entry", role: .destructive) {
                if let id = pendingDelete { delete(id) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Everything in this entry will be removed. You can duplicate an entry first if you want to keep a copy.")
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func delete(_ id: UUID) {
        section.entries.removeAll { $0.id == id }
        if expandedID == id { expandedID = nil }
    }
}
