// Suggests `add`, `delete` and every target in config/shell/cd-targets.
const targets = {
  script: ["grep", "-v", "^#", "/Users/danish/scripts/config/shell/cd-targets"],
  postProcess: (out) =>
    out
      .split("\n")
      .filter(Boolean)
      .map((line) => {
        const i = line.indexOf(" ");
        return { name: line.slice(0, i), description: line.slice(i + 1), icon: "📁" };
      }),
};

export default {
  name: "cd-",
  description: "Jump to a named directory",
  subcommands: [
    { name: "add", description: "Pick a directory and add it as a target", icon: "➕" },
    {
      name: "delete",
      description: "Remove targets",
      icon: "➖",
      args: { name: "target", isOptional: true, isVariadic: true, generators: targets },
    },
  ],
  args: { name: "target", generators: targets },
};
