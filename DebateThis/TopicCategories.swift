import Foundation

struct TopicCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let topics: [String]
}

enum TopicCategories {
    static let all: [TopicCategory] = [
        TopicCategory(
            id: "tech",
            name: "Technology",
            icon: "desktopcomputer",
            topics: [
                "Should AI systems be granted legal personhood?",
                "Is open-source AI safer than closed-source AI?",
                "Should social media algorithms be regulated by law?",
                "Will AI replace more jobs than it creates?",
                "Should there be a global pause on AI development?",
            ]
        ),
        TopicCategory(
            id: "society",
            name: "Society",
            icon: "person.3.fill",
            topics: [
                "Should voting be mandatory?",
                "Is social media a net positive for society?",
                "Should college education be free?",
                "Is remote work better than in-office work?",
                "Should the voting age be lowered to 16?",
            ]
        ),
        TopicCategory(
            id: "science",
            name: "Science",
            icon: "atom",
            topics: [
                "Is space exploration worth the cost?",
                "Should we terraform Mars?",
                "Are electric vehicles truly better for the environment?",
                "Should human genetic engineering be allowed?",
                "Is nuclear energy the best path to decarbonization?",
            ]
        ),
        TopicCategory(
            id: "philosophy",
            name: "Philosophy",
            icon: "brain",
            topics: [
                "Is free will an illusion?",
                "Can a machine ever be truly conscious?",
                "Is it ethical to eat meat?",
                "Does the trolley problem have a correct answer?",
                "Is privacy a right or a privilege?",
            ]
        ),
        TopicCategory(
            id: "fun",
            name: "Fun & Absurd",
            icon: "party.popper.fill",
            topics: [
                "Should pineapple go on pizza?",
                "Is a hot dog a sandwich?",
                "Would you rather fight one horse-sized duck or 100 duck-sized horses?",
                "Is water wet?",
                "Are cats better than dogs?",
            ]
        ),
        TopicCategory(
            id: "business",
            name: "Business",
            icon: "chart.line.uptrend.xyaxis",
            topics: [
                "Should companies enforce return-to-office mandates?",
                "Is the 4-day work week the future?",
                "Should CEOs have a maximum pay ratio vs median employee?",
                "Is cryptocurrency a legitimate asset class?",
                "Should Big Tech companies be broken up?",
            ]
        ),
    ]
}
