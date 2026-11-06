import Foundation

enum MockClipboardData {
    static func items() -> [ClipboardItem] {
        [
            ClipboardItem(
                type: .text,
                title: "docker run -d --name myapp -p 8080:80",
                subtitle: "nginx:latest",
                preview: "docker run -d --name myapp -p 8080:80 nginx:latest",
                content: "docker run -d --name myapp -p 8080:80 nginx:latest",
                sourceApp: "Terminal",
                createdAt: makeDate(dayOffset: 0, hour: 10, minute: 44),
                isPinned: true
            ),
            ClipboardItem(
                type: .email,
                title: "Investor update follow-up",
                subtitle: "Email template",
                preview: "Hi Alessia, thanks again for taking the time today...",
                content: """
                Hi Alessia,

                Thanks again for taking the time today. I’m attaching the latest numbers and a short summary of the product updates we discussed.

                Best,
                Luca
                """,
                sourceApp: "Mail",
                createdAt: makeDate(dayOffset: 0, hour: 10, minute: 37),
                isPinned: true
            ),
            ClipboardItem(
                type: .url,
                title: "https://developer.apple.com/design/",
                subtitle: "Apple Human Interface Guidelines",
                preview: "Apple Design Resources and Human Interface Guidelines",
                content: "https://developer.apple.com/design/",
                sourceApp: "Safari",
                createdAt: makeDate(dayOffset: 0, hour: 10, minute: 40)
            ),
            ClipboardItem(
                type: .color,
                title: "#0A84FF",
                subtitle: "rgb(10, 132, 255)",
                preview: "Accent color #0A84FF",
                content: "Accent color: #0A84FF",
                sourceApp: "Figma",
                createdAt: makeDate(dayOffset: 0, hour: 10, minute: 36)
            ),
            ClipboardItem(
                type: .code,
                title: "function debounce<T extends (...args: any[]) => any>",
                subtitle: "TypeScript utility",
                preview: "function debounce<T extends (...args: any[]) => any>(fn: T, delay: number) { ... }",
                content: """
                function debounce<T extends (...args: any[]) => any>(
                  fn: T,
                  delay: number
                ) {
                  let timer: ReturnType<typeof setTimeout>

                  return (...args: Parameters<T>) => {
                    clearTimeout(timer)
                    timer = setTimeout(() => fn(...args), delay)
                  }
                }
                """,
                sourceApp: "Visual Studio Code",
                createdAt: makeDate(dayOffset: 0, hour: 10, minute: 32)
            ),
            ClipboardItem(
                type: .image,
                title: "Image",
                subtitle: "1280 x 720",
                preview: "Mountain landscape thumbnail",
                content: "Image placeholder: mountain landscape, 1280 x 720",
                sourceApp: "CleanShot X",
                createdAt: makeDate(dayOffset: 0, hour: 10, minute: 15)
            ),
            ClipboardItem(
                type: .text,
                title: "Prendi appunti velocemente con uno strumento",
                subtitle: "Italian product copy",
                preview: "Prendi appunti velocemente con uno strumento semplice ed elegante.",
                content: "Prendi appunti velocemente con uno strumento semplice ed elegante.",
                sourceApp: "Notes",
                createdAt: makeDate(dayOffset: 0, hour: 9, minute: 58)
            ),
            ClipboardItem(
                type: .json,
                title: "{ \"status\": \"ok\", \"count\": 42 }",
                subtitle: "API response",
                preview: "{ \"status\": \"ok\", \"count\": 42 }",
                content: """
                {
                  "status": "ok",
                  "count": 42,
                  "items": [
                    { "id": "px_001", "type": "text" },
                    { "id": "px_002", "type": "url" }
                  ]
                }
                """,
                sourceApp: "Postman",
                createdAt: makeDate(dayOffset: 0, hour: 9, minute: 41)
            ),
            ClipboardItem(
                type: .url,
                title: "https://gist.github.com/",
                subtitle: "Saved reference",
                preview: "https://gist.github.com/",
                content: "https://gist.github.com/",
                sourceApp: "Arc",
                createdAt: makeDate(dayOffset: -1, hour: 18, minute: 18),
                isPinned: true
            ),
            ClipboardItem(
                type: .code,
                title: "SELECT * FROM users WHERE created_at > NOW()",
                subtitle: "SQL snippet",
                preview: "SELECT * FROM users WHERE created_at > NOW() - INTERVAL '7 days';",
                content: "SELECT * FROM users WHERE created_at > NOW() - INTERVAL '7 days';",
                sourceApp: "TablePlus",
                createdAt: makeDate(dayOffset: -1, hour: 16, minute: 52)
            ),
            ClipboardItem(
                type: .text,
                title: "Quarterly roadmap notes",
                subtitle: "Project planning",
                preview: "Focus the next iteration on speed, reliability, and keyboard-first flows.",
                content: "Focus the next iteration on speed, reliability, and keyboard-first flows.",
                sourceApp: "Notion",
                createdAt: makeDate(dayOffset: -1, hour: 12, minute: 9)
            ),
            ClipboardItem(
                type: .json,
                title: "Raycast-style command metadata",
                subtitle: "Prototype fixture",
                preview: "{ \"name\": \"Open Clipboard\", \"shortcut\": \"shift+cmd+v\" }",
                content: """
                {
                  "name": "Open Clipboard",
                  "shortcut": "shift+cmd+v",
                  "enabled": true
                }
                """,
                sourceApp: "Xcode",
                createdAt: makeDate(dayOffset: -2, hour: 14, minute: 24)
            )
        ]
    }

    private static func makeDate(dayOffset: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) ?? startOfDay
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
