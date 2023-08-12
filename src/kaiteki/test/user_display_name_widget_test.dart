import "package:kaiteki/ui/shared/users/user_display_name_widget.dart";
import "package:kaiteki_core/model.dart";
import "package:test/test.dart";

void main() {
  test("separated", () {
    const user = User(
      id: "",
      username: "alice",
      displayName: "Alice 🌈",
      host: "example.org",
    );

    final content = DisplayNameTuple.fromUser(user);
    expect(content.secondary, equals("@alice@example.org"));
    expect(content.separate, isTrue);
  });

  test("unseparated", () {
    const user = User(
      id: "",
      username: "alice",
      displayName: "Alice",
      host: "example.org",
    );

    final content = DisplayNameTuple.fromUser(user);
    expect(content.secondary, equals("@example.org"));
    expect(content.separate, isFalse);
  });
}
