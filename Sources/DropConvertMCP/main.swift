import Foundation
import DropConvertCore

Task {
    while let line = readLine() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { continue }
        guard let data = trimmed.data(using: .utf8),
              let req = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { continue }

        await handleRequest(req)
    }
    exit(0)
}

RunLoop.main.run()

// MARK: - Request handling

func handleRequest(_ req: [String: Any]) async {
    guard let method = req["method"] as? String else { return }
    let id = req["id"]

    // Notifications have no id and need no response
    if id == nil && method.hasPrefix("notifications/") { return }

    switch method {
    case "initialize":
        send([
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "result": [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [:]],
                "serverInfo": ["name": "dropconvert", "version": "1.0.0"]
            ]
        ])

    case "tools/list":
        send([
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "result": [
                "tools": [[
                    "name": "convert_file",
                    "description": "Convert a file to a different format. Supports: HEIC/JPG/PNG → JPG or PNG, MOV → MP4, PDF → JPG or PNG. Output is saved next to the input file.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [
                            "input_path": [
                                "type": "string",
                                "description": "Absolute path to the file to convert"
                            ],
                            "output_format": [
                                "type": "string",
                                "enum": ["jpg", "png", "mp4"],
                                "description": "Target format"
                            ]
                        ],
                        "required": ["input_path", "output_format"]
                    ]
                ]]
            ]
        ])

    case "tools/call":
        let params = req["params"] as? [String: Any] ?? [:]
        let toolName = params["name"] as? String ?? ""
        let args = params["arguments"] as? [String: Any] ?? [:]

        guard toolName == "convert_file" else {
            sendError(id: id, code: -32601, message: "Unknown tool: \(toolName)")
            return
        }

        guard let inputPath = args["input_path"] as? String,
              let formatStr = args["output_format"] as? String,
              let format = OutputFormat(rawValue: formatStr)
        else {
            sendError(id: id, code: -32602, message: "Invalid arguments: requires input_path (string) and output_format (jpg/png/mp4)")
            return
        }

        let inputURL = URL(fileURLWithPath: inputPath)

        do {
            let outputURL = try await ConversionEngine.convert(file: inputURL, to: format)
            send([
                "jsonrpc": "2.0",
                "id": id ?? NSNull(),
                "result": [
                    "content": [[
                        "type": "text",
                        "text": "Converted successfully. Output: \(outputURL.path)"
                    ]]
                ]
            ])
        } catch {
            send([
                "jsonrpc": "2.0",
                "id": id ?? NSNull(),
                "result": [
                    "content": [[
                        "type": "text",
                        "text": "Conversion failed: \(error.localizedDescription)"
                    ]],
                    "isError": true
                ]
            ])
        }

    default:
        sendError(id: id, code: -32601, message: "Method not found: \(method)")
    }
}

// MARK: - Helpers

func send(_ response: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: response),
          let line = String(data: data, encoding: .utf8)
    else { return }
    print(line)
}

func sendError(id: Any?, code: Int, message: String) {
    send([
        "jsonrpc": "2.0",
        "id": id ?? NSNull(),
        "error": ["code": code, "message": message]
    ])
}
