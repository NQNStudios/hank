package src;

class RunStoryDemo {
    public static function main() {
        var input = Sys.stdin();

        trace("Enter a path to a hank story file (default is examples/main.hank): ");
        var path = input.readLine();
        path = if (path.length == 0) {
            "examples/main.hank";
        } else {
            path;
        }

        var story: Story = new Story(path);
        var frame = StoryFrame.Empty;
        do {
            frame = story.nextFrame();
            switch (frame) {
                case HasText(text):
                    trace(text);
                case HasChoices(choices): 
                    for (index in 0... choices.length) {
                        var choice = choices[index];
                        trace('${index+1}. ${choice}');
                    }

                    var choiceIndex = Std.parseInt(input.readLine());
                    trace(choiceIndex);
                    trace(story.choose(choiceIndex-1));
                default:
            }
        } while (frame != Empty);

        trace("Story is finished.");

    }
}