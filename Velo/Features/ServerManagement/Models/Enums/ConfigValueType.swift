import Foundation

public enum ConfigValueType: String, Codable {
    case size       // e.g., upload_max_filesize
    case time       // e.g., max_execution_time
    case number     // e.g., max_input_vars
    case boolean    // e.g., display_errors
    case string     // e.g., date.timezone
}
