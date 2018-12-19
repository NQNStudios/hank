package src;

class StoryTest extends haxe.unit.TestCase {
    public static function main() {
        var r = new haxe.unit.TestRunner();
        r.add(new StoryTest());
        // add other TestCases here

        // finally, run the tests
        r.run();
    }

    public function testFullSpec() { 
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