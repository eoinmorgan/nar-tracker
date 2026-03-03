import Foundation

enum Constants {
    // MARK: - CDK outputs (NarTrackerStack)
    static let apiEndpoint      = "https://6sw4v7nahk.execute-api.us-west-1.amazonaws.com/log"
    static let awsRegion        = "us-west-1"
    static let cognitoDomain    = "https://nar-tracker.auth.us-west-1.amazoncognito.com"
    static let userPoolClientId = "53jsiuug0t7dag1jmn7lepkkb7"
    static let userPoolId       = "us-west-1_VOYSwxqpm"

    // MARK: - PurpleAir
    static let purpleAirApiKey = "12217058-1748-11F1-B596-4201AC1DC123"

    // MARK: - Notification schedule (hour, minute) in local time
    static let notificationTimes: [(hour: Int, minute: Int)] = [
        (8,  0),
        (11, 0),
        (14, 0),
        (17, 0),
        (20, 0),
    ]

    static let cognitoRedirectUri = "nartracker://callback"
}
