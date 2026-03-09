import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.helpTitle)
                            .font(.title2.bold())
                        Text(L.appSlogan)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                sectionTitle(L.helpCoreWorkflow, icon: "arrow.triangle.2.circlepath", color: .green)

                VStack(alignment: .leading, spacing: 12) {
                    flowStep("1", L.helpStep1Title, L.helpStep1Desc, color: .green)
                    flowStep("2", L.helpStep2Title, L.helpStep2Desc, color: .orange)
                    flowStep("3", L.helpStep3Title, L.helpStep3Desc, color: .blue)
                    flowStep("4", L.helpStep4Title, L.helpStep4Desc, color: .purple)
                }

                Divider()

                sectionTitle(L.helpFeatures, icon: "slider.horizontal.3", color: .blue)

                VStack(alignment: .leading, spacing: 10) {
                    featureItem("deskclock.fill", L.workDuration, L.helpFeatureWorkDuration)
                    featureItem("cup.and.saucer.fill", L.breakDuration, L.helpFeatureBreakDuration)
                    featureItem("target", L.dailyGoal, L.helpFeatureDailyGoal)
                    featureItem("rectangle.inset.filled", L.helpFeatureBreakPosTitle, L.helpFeatureBreakPos)
                    featureItem("hand.raised.fill", L.helpFeatureBreakConfirmTitle, L.helpFeatureBreakConfirm)
                    featureItem("speaker.wave.2.fill", L.helpFeatureSoundTitle, L.helpFeatureSound)
                    featureItem("ear.fill", L.helpFeatureDetectSoundTitle, L.helpFeatureDetectSound)
                    featureItem("arrow.counterclockwise", L.helpFeatureResetTitle, L.helpFeatureReset)
                    featureItem("pause.fill", L.helpFeaturePauseTitle, L.helpFeaturePause)
                    featureItem("trash", L.helpFeatureResetDataTitle, L.helpFeatureResetData)
                }

                Divider()

                sectionTitle(L.helpBreakWindow, icon: "macwindow", color: .orange)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L.helpBreakWindowDesc)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(L.helpBreakWindowDetect)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(L.helpBreakWindowSkip)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                sectionTitle(L.helpBadgeSystem, icon: "medal.fill", color: .yellow)

                Text(L.helpBadgeSystemDesc)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(L.helpBadgeStreak)
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(allBadges.enumerated()), id: \.offset) { _, badge in
                        badgeCard(badge)
                    }
                }

                Text(L.helpBadgeTotal)
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(allTotalBadges.enumerated()), id: \.offset) { _, badge in
                        badgeCard(badge)
                    }
                }

                Divider()

                sectionTitle(L.helpTips, icon: "lightbulb.fill", color: .green)

                VStack(alignment: .leading, spacing: 8) {
                    tipItem(L.helpTip1)
                    tipItem(L.helpTip2)
                    tipItem(L.helpTip3)
                    tipItem(L.helpTip4)
                    tipItem(L.helpTip5)
                }

                Divider()

                sectionTitle(L.helpUpdateSection, icon: "arrow.down.circle.fill", color: .purple)

                Text(L.helpUpdateDesc)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()

                sectionTitle(L.helpSponsorSection, icon: "heart.fill", color: .red)

                Text(L.helpSponsorDesc)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 24) {
                    Spacer()
                    sponsorImage("wechat-pay", label: L.wechatPay)
                    sponsorImage("alipay", label: L.alipay)
                    Spacer()
                }

                Text("\(L.helpSponsorThanks) ❤️")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 20)
            }
            .padding(32)
        }
        .frame(minWidth: 560, minHeight: 500)
    }

    private func sponsorImage(_ name: String, label: String) -> some View {
        let ext = name == "alipay" ? "png" : "jpg"
        return VStack(spacing: 6) {
            if let path = resolvePath(name: name, ext: ext),
               let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func resolvePath(name: String, ext: String) -> String? {
        let direct = Bundle.main.bundlePath + "/Contents/Resources/\(name).\(ext)"
        if FileManager.default.fileExists(atPath: direct) { return direct }
        if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url.path }
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources") { return url.path }
        return nil
    }

    private func sectionTitle(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
        }
    }

    private func flowStep(_ num: String, _ title: String, _ desc: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text(num)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.bold())
                Text(desc)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func featureItem(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.green)
                .frame(width: 20, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.bold())
                Text(desc)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func badgeCard(_ badge: Badge) -> some View {
        HStack(spacing: 10) {
            Text(badge.icon)
                .font(.system(size: 24))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(badge.name)
                    .font(.system(size: 13, weight: .semibold))
                Text(badge.desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(10)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }

    private func tipItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.green)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
