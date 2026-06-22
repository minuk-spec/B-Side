import SwiftUI

struct TutorialView: View {
    var onClose: () -> Void
    @State private var currentStep = 0

    let steps: [TutorialStep] = [
        TutorialStep(
            icon: "cursorarrow.rays",
            iconColor: Color(red: 0.3, green: 0.6, blue: 1.0),
            title: "단어 위에 마우스를 올리면",
            description: "상단바 단어에 마우스를 올리면\n단어의 뜻이 바로 표시됩니다.",
            hint: "빠르게 뜻을 확인할 때 사용하세요"
        ),
        TutorialStep(
            icon: "cursorarrow",
            iconColor: Color(red: 0.2, green: 0.75, blue: 0.5),
            title: "클릭하면 상세 정보",
            description: "단어를 클릭하면 뜻, 예문, 예문 해석을\n한눈에 볼 수 있습니다.",
            hint: "예문까지 한번에 확인하세요"
        ),
        TutorialStep(
            icon: "cursorarrow.click.2",
            iconColor: Color(red: 1.0, green: 0.6, blue: 0.1),
            title: "우클릭으로 단어 관리",
            description: "단어에 우클릭하면 단어목록 창이 열립니다.\n단어 추가·삭제·설정을 할 수 있어요.",
            hint: "◀ ▶ 버튼으로 단어를 넘길 수도 있어요"
        )
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)

            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Text("B-Side 사용법")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(currentStep + 1) / \(steps.count)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20).padding(.vertical, 14)

                Divider().padding(.horizontal, 8)

                // 콘텐츠 영역 390px 고정
                VStack(spacing: 0) {
                    Spacer()

                    // 아이콘
                    ZStack {
                        Circle()
                            .fill(steps[currentStep].iconColor.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 34, weight: .light))
                            .foregroundColor(steps[currentStep].iconColor)
                    }
                    .padding(.bottom, 28)

                    // 타이틀
                    Text(steps[currentStep].title)
                        .font(.system(size: 17, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)

                    // 설명
                    Text(steps[currentStep].description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    // 힌트
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text(steps[currentStep].hint)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(8)

                    Spacer()

                    // 스텝 인디케이터
                    HStack(spacing: 6) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Circle()
                                .fill(i == currentStep ? Color.blue : Color.secondary.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .animation(.easeInOut(duration: 0.2), value: currentStep)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .frame(height: 390)

                Divider().padding(.horizontal, 8)

                // 푸터
                HStack {
                    if currentStep > 0 {
                        Button("이전") { withAnimation { currentStep -= 1 } }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if currentStep < steps.count - 1 {
                        Button(action: { withAnimation { currentStep += 1 } }) {
                            HStack(spacing: 4) {
                                Text("다음")
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11))
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: onClose) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("시작하기")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .frame(width: 300)
    }
}

struct TutorialStep {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let hint: String
}
