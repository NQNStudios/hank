package src;

enum StoryFrame {
    HasText(text: String);
    HasChoices(choices: Array<String>);
    Error(message: String);
    Empty; // Returned by Hank statements that have no output
    Finished; // Returned when the Hank story is finished or has crashed
}