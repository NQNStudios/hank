package src;

enum StoryFrame {
    HasText(text: String);
    HasChoices(choices: Array<String>);
    Empty;
}