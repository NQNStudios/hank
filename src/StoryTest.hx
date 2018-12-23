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

    public function testFullSpec1() {
        var story: Story = new Story("examples/main.hank");
        assertEquals("HasText(This is a section of a Hank story. It's pretty much like a Knot in Ink.)", Std.string(story.nextFrame()));
        assertEquals("HasText(Line breaks define the chunks of this section that will eventually get sent to your game to process.)", Std.string(story.nextFrame()));
        assertEquals("HasText(Your Hank scripts will contain the static content of your game, but they can also insert dynamic content, even the result of complex haxe expressions!)", Std.string(story.nextFrame()));
        assertEquals("HasText(You can include choices for the player.)", Std.string(story.nextFrame()));

        assertEquals("HasChoices([Door A,Door B opens but the room on the other side is identical!])", Std.string(story.nextFrame()));

        assertEquals("Door A opens and there's nothing behind it.", story.choose(0));

        assertEquals("HasText(You can include choices for the player.)", Std.string(story.nextFrame()));
        assertEquals("HasChoices([Door B opens but the room on the other side is identical!,Choices can depend on logical conditions being truthy.])", Std.string(story.nextFrame()));

        assertEquals("Door B opens but the room on the other side is identical!", story.choose(0)); 
        assertEquals("HasText(You can include choices for the player.)", Std.string(story.nextFrame()));
        assertEquals("HasChoices([Door B opens but the room on the other side is identical!,Choices can depend on logical conditions being truthy.])", Std.string(story.nextFrame()));
        assertEquals("Door B opens but the room on the other side is identical!", story.choose(0)); 
        assertEquals("HasText(You can include choices for the player.)", Std.string(story.nextFrame()));
        assertEquals("HasChoices([Door B opens but the room on the other side is identical!,Choices can depend on logical conditions being truthy.])", Std.string(story.nextFrame()));
        assertEquals("Door B opens but the room on the other side is identical!", story.choose(0)); 
        assertEquals("HasText(You can include choices for the player.)", Std.string(story.nextFrame()));
        assertEquals("HasChoices([Door B opens but the room on the other side is identical!,Choices can depend on logical conditions being truthy.])", Std.string(story.nextFrame()));

        assertEquals("Choices can depend on logical conditions being truthy.", story.choose(1));

        assertEquals("HasChoices([I don't think I'll use Hank for my games.,Hank sounds awesome, thanks!])", Std.string(story.nextFrame()));
        assertEquals("I don't think I'll use Hank for my games.", story.choose(0));
        assertEquals("HasText(Are you sure?)", Std.string(story.nextFrame()));
        assertEquals("HasChoices([Yes I'm sure.,I've changed my mind.])", Std.string(story.nextFrame()));
        assertEquals("Yes I'm sure.", story.choose(0));
        assertEquals("HasText(That's perfectly valid!)", Std.string(story.nextFrame()));
        assertEquals(StoryFrame.Empty, story.nextFrame());
    }
}