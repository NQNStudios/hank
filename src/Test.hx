package src;

class Test {
    public static function main() {
        var story: Story = new Story("spec/main.hank");
        var frame = StoryFrame.Empty;
        do {
            frame = story.currentFrame();
            switch (frame) {
                case HasText(text):
                    trace(text);
                case HasChoices(choices): 
                    for (index in 1... choices.length) {
                        var choice = choices[index-1];
                        trace("${index}. ${choice}");
                    }

                    // TODO accept choice and follow it
                default:
            }
        } while (frame != Empty);

        trace("Story is finished.");
    }
}