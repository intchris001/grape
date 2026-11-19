import SwiftUI

enum AppStyle {
    enum Palette {
        // Dreamy Pastel Theme - Soft Lilac & Cherry Blossom Pink (Gentle & Romantic)
        static let canvas = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.12, green: 0.08, blue: 0.14, alpha: 1.0) : UIColor(red: 0.98, green: 0.96, blue: 0.98, alpha: 1.0)
        })
        static let surface = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.18, green: 0.13, blue: 0.20, alpha: 1.0) : UIColor.white
        })
        static let surfaceMuted = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.24, green: 0.18, blue: 0.26, alpha: 1.0) : UIColor(red: 0.96, green: 0.92, blue: 0.96, alpha: 1.0)
        })

        // Soft Lilac (Primary)
        static let primary = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.75, green: 0.60, blue: 0.90, alpha: 1.0) : UIColor(red: 0.65, green: 0.50, blue: 0.85, alpha: 1.0)
        })
        // Extremely gentle translucent lilac for backgrounds
        static let primarySoft = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.35, green: 0.25, blue: 0.45, alpha: 1.0) : UIColor(red: 0.92, green: 0.88, blue: 0.98, alpha: 1.0)
        })
        
        // Cherry Blossom Pink (Accent - replacing the orange)
        static let accent = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.95, green: 0.60, blue: 0.75, alpha: 1.0) : UIColor(red: 0.95, green: 0.55, blue: 0.70, alpha: 1.0)
        })

        // Gradient track (Pink to Lilac)
        static let progressStart = Color(red: 0.95, green: 0.55, blue: 0.70) // Pink start
        static let progressEnd = Color(red: 0.65, green: 0.50, blue: 0.85)   // Lilac end
        static let progressTrack = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.25, green: 0.15, blue: 0.25, alpha: 1.0) : UIColor(red: 0.96, green: 0.90, blue: 0.94, alpha: 1.0)
        })
        
        static let canvasGradient = LinearGradient(
            colors: [
                Color(UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.25, green: 0.12, blue: 0.22, alpha: 1.0) : UIColor(red: 1.0, green: 0.92, blue: 0.96, alpha: 1.0)
                }), // Pinkish
                Color(UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.15, green: 0.10, blue: 0.25, alpha: 1.0) : UIColor(red: 0.92, green: 0.88, blue: 0.98, alpha: 1.0)
                })  // Lilac
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let separator = Color.primary.opacity(0.12)
        static let glassHighlight = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.05) : UIColor.white.withAlphaComponent(0.15)
        })
        static let glassShadow = Color.black.opacity(0.2)
    }

    enum Radius {
        static let card: CGFloat = 16 // Sharper corners for a structural feel
        static let capsule: CGFloat = 8
        static let iconCircle: CGFloat = 18
    }

    enum Shadow {
        static let cardColor = Palette.primary.opacity(0.16)
        static let cardRadius: CGFloat = 12
        static let cardY: CGFloat = 4
    }

    enum Typography {
        static let titleXL = Font.system(size: 48, weight: .black, design: .serif) // Switching to Serif for titles
        static let titleL = Font.system(size: 36, weight: .heavy, design: .serif)
        static let titleM = Font.system(size: 28, weight: .bold, design: .serif)
        static let section = Font.system(size: 20, weight: .bold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyStrong = Font.system(size: 17, weight: .semibold, design: .default)
        static let label = Font.system(size: 15, weight: .bold, design: .default)
        static let caption = Font.system(size: 13, weight: .semibold, design: .default)
        static let tiny = Font.system(size: 12, weight: .medium, design: .default)
        static let numericTime = Font.system(size: 16, weight: .bold, design: .monospaced).monospacedDigit()
    }

    enum Haptic {
        static func play(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }

        static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
        
        static func selection() {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }
}

enum FinancePalette {
    static let panel = Color.white.opacity(0.72)
    
    // Dreamy Pastel Palette for Finance Categories
    static let grape = AppStyle.Palette.primary
    static let grapeDeep = Color(red: 0.55, green: 0.40, blue: 0.75)
    static let grapeMid = Color(red: 0.70, green: 0.55, blue: 0.88)
    static let grapeMist = Color(red: 0.95, green: 0.92, blue: 0.98)
    
    static let mint = Color(red: 0.60, green: 0.85, blue: 0.75) // Soft mint green
    static let mintSoft = Color(red: 0.85, green: 0.95, blue: 0.90)
    
    static let sunny = Color(red: 0.98, green: 0.85, blue: 0.55) // Soft butter yellow
    
    static let income = Color(red: 0.55, green: 0.80, blue: 0.65) // Gentle green
    static let expense = Color(red: 0.95, green: 0.55, blue: 0.65) // Soft rose pink
    
    static let amber = Color(red: 0.95, green: 0.75, blue: 0.50) // Soft peach
    static let cyan = Color(red: 0.55, green: 0.80, blue: 0.85) // Baby blue
    static let lilac = Color(red: 0.75, green: 0.65, blue: 0.90) // Lavender

    static func color(for category: FinancialCategory) -> Color {
        switch category {
        case .groceries: return income
        case .dining: return amber
        case .transport: return cyan
        case .home: return grape
        case .education: return lilac
        case .health: return Color(red: 0.86, green: 0.38, blue: 0.56)
        case .income: return income
        case .savings: return grape
        case .other: return Color(red: 0.53, green: 0.56, blue: 0.66)
        }
    }

    static func symbol(for category: FinancialCategory) -> String {
        switch category {
        case .groceries: return "cart.fill"
        case .dining: return "fork.knife"
        case .transport: return "car.fill"
        case .home: return "house.fill"
        case .education: return "book.fill"
        case .health: return "cross.case.fill"
        case .income: return "dollarsign.circle.fill"
        case .savings: return "banknote.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

struct GlassPanel: ViewModifier {
    let cornerRadius: CGFloat
    let strokeOpacity: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppStyle.Palette.surface.opacity(0.92)) // More opaque surface
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppStyle.Palette.primary.opacity(0.15), lineWidth: 1.5) // Stronger border
            )
            .shadow(color: AppStyle.Shadow.cardColor, radius: AppStyle.Shadow.cardRadius, x: 0, y: AppStyle.Shadow.cardY)
    }
}

struct GlassInputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppStyle.Typography.body)
            .foregroundStyle(AppStyle.Palette.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppStyle.Radius.capsule, style: .continuous)
                    .fill(AppStyle.Palette.surfaceMuted.opacity(0.8)) // Darker input field background
                    .overlay(
                        RoundedRectangle(cornerRadius: AppStyle.Radius.capsule, style: .continuous)
                            .stroke(AppStyle.Palette.primary.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = AppStyle.Radius.card, strokeOpacity: CGFloat = 0.92) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }

    func glassInputField() -> some View {
        modifier(GlassInputFieldModifier())
    }
}
