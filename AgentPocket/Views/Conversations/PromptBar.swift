import SwiftUI
import AVFoundation

enum InputState {
    case idle
    case recording
    case previewing(PreviewContent)
}

struct PromptBar: View {
    let conversationID: ConversationID
    @Environment(AppState.self) private var appState
    
    @State private var text = ""
    @State private var inputState: InputState = .idle
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isPulsing = false
    
    private var isPreviewing: Bool {
        if case .previewing = inputState { return true }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Theme.surface)
            
            if case .previewing(let content) = inputState {
                MediaPreview(content: content, onSend: {
                    sendMessage()
                }, onDiscard: {
                    withAnimation(Theme.springAnimation) {
                        inputState = .idle
                    }
                })
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                if case .recording = inputState {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                            .opacity(isPulsing ? 0.3 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                            .onAppear { isPulsing = true }
                            .onDisappear { isPulsing = false }
                        
                        Text("Recording...")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.bottom, 12)
                    .padding(.leading, 4)
                    
                    Spacer()
                } else {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.bottom, 8)
                    
                    TextField("Message...", text: $text, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(10)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .foregroundStyle(Theme.textPrimary)
                }
                
                if text.isEmpty && !isPreviewing {
                    VoiceRecordButton(isRecording: Binding(
                        get: {
                            if case .recording = inputState { return true }
                            return false
                        },
                        set: { isRecording in
                            withAnimation(Theme.springAnimation) {
                                if isRecording {
                                    inputState = .recording
                                } else if case .recording = inputState {
                                    inputState = .idle
                                }
                            }
                        }
                    )) { audioData in
                        let duration = (try? AVAudioPlayer(data: audioData))?.duration ?? 0
                        withAnimation(Theme.springAnimation) {
                            inputState = .previewing(.audio(data: audioData, duration: duration))
                        }
                    }
                    .padding(.bottom, 4)
                } else if !isPreviewing {
                    Button {
                        HapticManager.impact(.light)
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Theme.cyanAccent)
                    }
                    .padding(.bottom, 2)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Theme.background)
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerButton(image: $selectedImage)
        }
        .onChange(of: selectedImage) { _, image in
            if let image {
                withAnimation(Theme.springAnimation) {
                    inputState = .previewing(.image(image))
                }
                selectedImage = nil
            }
        }
    }
    
    private func sendMessage() {
        var contents: [MessageContent] = []
        
        if case .previewing(let preview) = inputState {
            switch preview {
            case .image(let image):
                if let data = image.jpegData(compressionQuality: 0.8) {
                    contents.append(MessageContent(
                        type: .image,
                        data: .image(ImageContent(data: data, mimeType: "image/jpeg"))
                    ))
                }
            case .audio(let data, _):
                contents.append(MessageContent(
                    type: .audio,
                    data: .audio(AudioContent(data: data, mimeType: "audio/m4a"))
                ))
            }
        }
        
        if !text.isEmpty {
            contents.append(MessageContent(
                type: .text,
                data: .text(TextContent(text: text))
            ))
        }
        
        guard !contents.isEmpty else { return }
        
        let message = Message(
            id: UUID().uuidString,
            conversationID: conversationID,
            role: .user,
            content: contents
        )
        
        appState.conversationStore.addOrUpdateMessage(message, for: conversationID)
        
        text = ""
        withAnimation(Theme.springAnimation) {
            inputState = .idle
        }
        
        Task {
            await appState.sendMessage(conversationID: conversationID, content: contents)
            HapticManager.notification(.success)
        }
    }
}
