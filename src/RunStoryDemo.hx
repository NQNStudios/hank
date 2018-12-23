package src;

class RunStoryDemo {
    public static function main() {
        var input = Sys.stdin();

        var debug = false;
        trace("Enter a path to a hank story file. Prepend with * for debug prints. (default is examples/main.hank): ");
        var path = input.readLine();
        path = if (path.length == 0) {
            "examples/main.hank";
        } else {
            if (path.charAt(0) == '*') {
                debug = true;
                path.substr(1);
            } else {
                path;
            }
        }

        var story: Story = new Story(false);
        story.loadScript(path);
        var frame = StoryFrame.Finished;
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
        } while (frame != Finished);

        trace("Story is finished.");

    }
}