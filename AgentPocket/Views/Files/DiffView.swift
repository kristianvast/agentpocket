import SwiftUI

struct DiffView: View {
    let diffs: [FileDiff]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(diffs, id: \.path) { diff in
                    FileDiffSection(diff: diff)
                }
            }
            .padding()
        }
        .background(Brand.background)
    }
}

struct FileDiffSection: View {
    let diff: FileDiff
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(Brand.textMuted)
                        .frame(width: 20)
                }
                
                Text(diff.path)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                // MARK: - Status Badge
                Text(statusText)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
                
                // MARK: - Stats
                HStack(spacing: 8) {
                    if diff.additions > 0 {
                        Text("+\(diff.additions)")
                            .foregroundColor(Brand.success)
                            .font(.caption.monospacedDigit())
                    }
                    if diff.deletions > 0 {
                        Text("-\(diff.deletions)")
                            .foregroundColor(Brand.error)
                            .font(.caption.monospacedDigit())
                    }
                }
            }
            .padding()
            .background(Brand.surface)
            
            // MARK: - Content
            if isExpanded {
                Divider()
                    .background(Brand.border)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(parsedLines.enumerated()), id: \.offset) { index, line in
                            DiffLineRow(line: line)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Brand.surfaceLight)
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Brand.border, lineWidth: 1)
        )
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        switch diff.status {
        case .added: return "ADDED"
        case .modified: return "MODIFIED"
        case .deleted: return "DELETED"
        }
    }
    
    private var statusColor: Color {
        switch diff.status {
        case .added: return Brand.success
        case .modified: return Brand.warning
        case .deleted: return Brand.error
        }
    }
    
    private var parsedLines: [DiffLine] {
        var lines: [DiffLine] = []
        let rawLines = diff.patch.components(separatedBy: .newlines)
        
        var oldLineNum = 0
        var newLineNum = 0
        
        for rawLine in rawLines {
            if rawLine.hasPrefix("@@") {
                lines.append(DiffLine(type: .hunk, content: rawLine, oldLine: nil, newLine: nil))
                
                let parts = rawLine.split(separator: " ")
                if parts.count >= 3 {
                    let oldPart = parts[1].dropFirst()
                    let newPart = parts[2].dropFirst()
                    
                    if let oldStart = Int(oldPart.split(separator: ",")[0]) {
                        oldLineNum = oldStart
                    }
                    if let newStart = Int(newPart.split(separator: ",")[0]) {
                        newLineNum = newStart
                    }
                }
            } else if rawLine.hasPrefix("+") {
                lines.append(DiffLine(type: .addition, content: rawLine, oldLine: nil, newLine: newLineNum))
                newLineNum += 1
            } else if rawLine.hasPrefix("-") {
                lines.append(DiffLine(type: .deletion, content: rawLine, oldLine: oldLineNum, newLine: nil))
                oldLineNum += 1
            } else if rawLine.hasPrefix(" ") {
                lines.append(DiffLine(type: .context, content: rawLine, oldLine: oldLineNum, newLine: newLineNum))
                oldLineNum += 1
                newLineNum += 1
            } else {
                lines.append(DiffLine(type: .context, content: rawLine, oldLine: nil, newLine: nil))
            }
        }
        
        return lines
    }
}

struct DiffLine {
    enum LineType {
        case addition
        case deletion
        case context
        case hunk
    }
    
    let type: LineType
    let content: String
    let oldLine: Int?
    let newLine: Int?
}

struct DiffLineRow: View {
    let line: DiffLine
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // MARK: - Line Numbers
            HStack(spacing: 0) {
                Text(line.oldLine.map { "\($0)" } ?? "")
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
                
                Text(line.newLine.map { "\($0)" } ?? "")
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(Brand.textMuted)
            .background(lineColor.opacity(0.5))
            
            // MARK: - Content
            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(textColor)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(lineColor)
        }
    }
    
    // MARK: - Computed Properties
    
    private var lineColor: Color {
        switch line.type {
        case .addition: return Brand.success.opacity(0.15)
        case .deletion: return Brand.error.opacity(0.15)
        case .hunk: return Brand.cyan.opacity(0.1)
        case .context: return .clear
        }
    }
    
    private var textColor: Color {
        switch line.type {
        case .addition: return Brand.success
        case .deletion: return Brand.error
        case .hunk: return Brand.cyan
        case .context: return Brand.textPrimary
        }
    }
}
