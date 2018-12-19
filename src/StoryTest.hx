package src;

class StoryTest extends haxe.unit.TestCase {
    public static function main() {
        var r = new haxe.unit.TestRunner();
        r.add(new StoryTest());
        // add other TestCases here

        // finally, run the tests
        r.run();
    }

    public function testHelloWorld() {
        var story: Story = new Story("examples/hello.hank");
        assertEquals('HasText(Hello, world!)', Std.string(story.nextFrame()));
        assertEquals(StoryFrame.Empty, story.nextFrame());
        assertEquals(StoryFrame.Empty, story.nextFrame());
    }

    public function testFullSpec() {
        var story: Story = new Story("examples/main.hank");
        assertEquals("HasText(This is a section of a Hank story. It's pretty much like a Knot in Ink.)", Std.string(story.nextFrame()));
        assertEquals("HasText(Line breaks define the chunks of this section that will eventually get sent to your game to process.)", Std.string(story.nextFrame()));
        assertEquals("HasText(Your Hank scripts will contain the static content of your game, but they can also insert dynamic content, even the result of complex haxe expressions!)", Std.string(story.nextFrame()));
    }

    public function interactiveTest() { 
        var story: Story = new Story("examples/main.hank");
        var frame = StoryFrame.Empty;
        do {
            frame = story.nextFrame();
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