import js.html.*;
import js.Browser.*;

class Web {
    static function main() {
        var code:TextAreaElement = cast document.getElementById("code");
        var tree:PreElement = cast document.getElementById("tree");

        function update() {
            var scanner = new Scanner(code.value);
            var tokens = [];
            var token;
            do {
                token = scanner.scan();
                tokens.push('<span class="token">${token.kind} <span class="pos">${token.pos}</span></span>');
                if (token.leadTrivia != null) {
                    tokens.push("  Lead trivia:");
                    for (trivia in token.leadTrivia)
                        tokens.push('    <span class="trivia">${trivia.kind} <span class="pos">${trivia.pos}</span></span>');
                }
                if (token.trailTrivia != null) {
                    tokens.push("  Trail trivia:");
                    for (trivia in token.trailTrivia)
                        tokens.push('    <span class="trivia">${trivia.kind} <span class="pos">${trivia.pos}</span></span>');
                }
            } while (token.kind != TkEof);
            tree.innerHTML = tokens.join("\n");
        }

        code.oninput = update;
        update();
    }
}