from __future__ import annotations
import io
from pathlib import Path

from railroad import (
    Terminal,
    DiagramItem,
    Diagram,
    Choice,
    Optional,
    OptionalSequence,
    NonTerminal,
    ZeroOrMore,
    Group,
    Stack,
    Sequence,
    OneOrMore,
    HorizontalChoice,
    Skip,
)


def ensure_diagram(diagram_item: DiagramItem) -> Diagram:
    if isinstance(diagram_item, Diagram):
        return diagram_item
    return Diagram(diagram_item)


def diagram(diagram_item: DiagramItem) -> Diagram:
    if isinstance(diagram_item, Diagram):
        raise ValueError("diagram_item must not be a Diagram")
    # type="complex" actually makes the diagram simpler by using single | at the
    # beginning and end e.g. |- ... -| rather than ||- ... --||
    return Diagram(diagram_item, type="complex")


# Key
def flags() -> DiagramItem:
    return OneOrMore(Choice(1, Terminal("+"), Terminal("~"), Terminal("?")))


def key_escape() -> DiagramItem:
    return HorizontalChoice(Terminal("::"), Terminal("=="), Terminal("@@"))


def key_chars():
    key_char = NonTerminal("Any char except :=@")
    return OneOrMore(Choice(1, key_escape(), key_char))


def key_value() -> DiagramItem:
    start_of_bare_key = NonTerminal("Any char except .+~?:=@")
    start_of_ref = Group(Terminal("@"), "reference")
    start_of_key = Choice(1, start_of_ref, start_of_bare_key, Terminal("="))

    return Sequence(start_of_key, key_chars())


def key() -> DiagramItem:
    return Sequence(Optional(NonTerminal("flags")), Optional(NonTerminal("key-value")))


def no_metadata_key() -> DiagramItem:
    not_flag_or_start_char = NonTerminal("Any char except +~?:=@")
    non_flag_key_char = Choice(1, key_escape(), not_flag_or_start_char)
    # return Sequence(NonTerminal("key-value"), non_flag_key_char)

    return Sequence(
        Optional(NonTerminal("flags")),
        Choice(0, Sequence(NonTerminal("key-value"), non_flag_key_char), Skip()),
    )


# Meta
def type() -> DiagramItem:
    return HorizontalChoice(
        Terminal("string"),
        Terminal("number"),
        Terminal("bool"),
        Terminal("true"),
        Terminal("false"),
        Terminal("null"),
        Terminal("raw"),
        Terminal("auto"),
    )


def object_collection() -> DiagramItem:
    split_char = Group(NonTerminal("Any char"), "split")
    object_format = Sequence(
        Terminal(":"), Group(Choice(0, Terminal("attrs"), Terminal("json")), "format")
    )
    object_collection = Sequence(
        "{", Optional(split_char), Optional(object_format), "}"
    )
    return object_collection


def array_collection() -> DiagramItem:
    split_char = Group(NonTerminal("Any char"), "split")
    array_format = Sequence(
        Terminal(":"), Group(Choice(0, Terminal("raw"), Terminal("json")), "format")
    )
    array_collection = Sequence("[", Optional(split_char), Optional(array_format), "]")
    return array_collection


def collection() -> DiagramItem:
    return HorizontalChoice(
        NonTerminal("array-collection"), NonTerminal("object-collection")
    )


def attribute_name() -> DiagramItem:
    return OneOrMore(Choice(0, NonTerminal("Any char except /,="), "==", ",,", "//"))


def attribute_value() -> DiagramItem:
    return ZeroOrMore(Choice(0, NonTerminal("Any char except /,"), ",,", "//"))


def attribute() -> DiagramItem:
    return Sequence(
        NonTerminal("attribute-name"),
        Optional(Sequence("=", NonTerminal("attribute-value"))),
    )


def attributes() -> DiagramItem:
    return Sequence("/", ZeroOrMore(NonTerminal("attribute"), repeat=","), "/")


def metadata() -> DiagramItem:
    return Sequence(
        Terminal(":"),
        Optional(NonTerminal("type")),
        Optional(NonTerminal("collection")),
        Optional(NonTerminal("attributes")),
    )


def value() -> DiagramItem:
    value_start = Choice(1, Group("@", "ref"), "=")
    return Sequence(Optional(NonTerminal("flags")), value_start, "Any char")


def argument() -> DiagramItem:
    key_and_meta = Choice(
        1,
        Skip(),
        Sequence(Optional(NonTerminal("key")), NonTerminal("metadata")),
        NonTerminal("no-metadata-key"),
    )
    return Sequence(
        Optional(Group("...", "splat")),
        key_and_meta,
        Optional(NonTerminal("value")),
    )


def minimal_arg() -> DiagramItem:
    """A high-level summary of the argument structure."""
    return Sequence(
        Optional(NonTerminal("key")),
        Choice(0, Sequence(":", Optional(NonTerminal("type"))), Skip()),
        Optional(Sequence(Choice(0, "=", "@"), NonTerminal("value"))),
    )


def approx_arg() -> DiagramItem:
    """A simplified argument grammar that ignores some details.

    Intended to give a good overview of the argument structure, but aiming to
    communicate a broad overview, not exact details.
    """
    flags = lambda name: Group(OneOrMore(Choice(1, "+", "~", "?")), f"{name} flags")
    simple_key = Sequence(
        Optional(flags("key")),
        Choice(1, Skip(), Group("@", "ref"), "="),
        Optional(NonTerminal("key")),
    )
    simple_meta = Sequence(
        ":",
        Group(Choice(1, Skip(), "string", "number", NonTerminal("...")), "type"),
        Group(
            Choice(1, Skip(), "[]", "{}", NonTerminal("...")),
            "collection",
        ),
        Group(
            Optional(Sequence("/", ZeroOrMore(NonTerminal("key=val"), ","), "/")),
            "attributes",
        ),
    )
    simple_value = Sequence(
        Optional(flags("value")),
        Optional(Sequence(Choice(0, Group("@", "ref"), "="), NonTerminal("value"))),
    )
    return Stack(
        Sequence(Group(Optional("..."), "splat"), simple_key),
        Optional(simple_meta),
        simple_value,
    )


def render_diagram(
    diagram: Diagram, *, standalone: bool = False, css: str | None = None
) -> str:
    out = io.StringIO()
    if standalone:
        diagram.writeStandalone(out.write, css=css)
    else:
        diagram.writeSvg(write=out.write)
    return out.getvalue()


def render_html(diagrams: dict[str, Diagram]) -> str:
    sections = [
        f"<h2>{name}</h2>\n{render_diagram(diagram)}"
        for (name, diagram) in diagrams.items()
    ]
    nl = "\n"
    style = """
:root {
  --body-bg: white;
  --body-color: black;
}

@media (prefers-color-scheme: dark) {
  :root {
    --body-bg: rgb(34 39 46);
    --body-color: rgb(173, 186, 199);
  }
}

body {
  background: var(--body-bg);
  color: var(--body-color);
}
"""
    return f"""\
<!doctype html>
<html>

<head>
  <meta charset="UTF-8">
  <title>Diagram</title>
  <style>{style}</style>
  <link rel="stylesheet" href="diagram.css">
</head>

<body>
<h1>Diagrams</h1>
{nl.join(sections)}
</body>

</html>

"""


def main():
    css = (Path(__file__).parent / "diagram.css").read_text()
    diagrams = {
        "minimal-argument": diagram(minimal_arg()),
        "approximate-argument": diagram(approx_arg()),
        "flags": diagram(flags()),
        "key-value": diagram(key_value()),
        "key": diagram(key()),
        "no-metadata-key": diagram(no_metadata_key()),
        "object-collection": diagram(object_collection()),
        "array-collection": diagram(array_collection()),
        "collection": diagram(collection()),
        "attribute-name": diagram(attribute_name()),
        "attribute-value": diagram(attribute_value()),
        "attribute": diagram(attribute()),
        "attributes": diagram(attributes()),
        "metadata": diagram(metadata()),
        "type": diagram(type()),
        "value": diagram(value()),
        "argument": diagram(argument()),
    }
    diagram_html = render_html(diagrams)
    Path("diagram.html").write_text(diagram_html)

    for name, diag in diagrams.items():
        Path(f"{name}.svg").write_text(render_diagram(diag, standalone=True, css=css))


if __name__ == "__main__":
    main()
