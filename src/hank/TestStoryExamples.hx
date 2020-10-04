package hank;

using StringTools;
import hiss.StaticFiles;

class TestStoryExamples {
    public static function main() {
        StaticFiles.compileWithAll("examples");

        var examples = sys.FileSystem.readDirectory("src/hank/examples");

        for (example in examples) {
            var transcripts = sys.FileSystem.readDirectory("src/hank/examples/" + example);
            transcripts = transcripts.filter((file) -> file.endsWith(".hlog"));
            
            for (transcript in transcripts) {
                Sys.println(example + " " + transcript);
                new Story("examples/" + example + "/main.hank", new StoryTester("examples/" + example + "/" + transcript)).run();
            }
        }
    }
}