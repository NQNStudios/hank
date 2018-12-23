package src;

enum StoryFrame {
    HasText(text: String);
    HasChoices(choices: Array<String>);
    Error(message: String);
    Finished;
}