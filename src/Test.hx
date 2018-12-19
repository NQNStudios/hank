package src;

class Test {
    public static function main() {
        var story: Story = new Story("spec/main.hank");
        while (story.currentFrame() != Empty) {
            switch (story.currentFrame()) {
                case HasText(text):
                    trace(text);
                case HasChoices(choices): 
                    for (index in 1... choices.length) {
                        var choice = choices[index-1];
                        trace("${index}. ${choice}");
                    }
                default:
            }
        }

        trace("Story is finished.");
    }
}