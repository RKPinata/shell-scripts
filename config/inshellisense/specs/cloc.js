// Suggests the subcommands and every plugin in config/claude/local-plugins.
const plugins = {
  script: ["grep", "-v", "-e", "^#", "-e", "^$", "/Users/danish/scripts/config/claude/local-plugins"],
  postProcess: (out) =>
    out
      .split("\n")
      .filter(Boolean)
      .map((line) => {
        const i = line.indexOf(" ");
        return { name: line.slice(0, i), description: line.slice(i + 1), icon: "🧩" };
      }),
};

export default {
  name: "cloc",
  description: "Start Claude with local plugin checkouts",
  subcommands: [
    { name: "all", description: "Load every plugin", icon: "📦" },
    {
      name: "add",
      description: "Register a plugin directory",
      icon: "➕",
      args: { name: "dir", isOptional: true, template: "folders" },
    },
    {
      name: "delete",
      description: "Remove plugins from the registry",
      icon: "➖",
      args: { name: "plugin", isOptional: true, isVariadic: true, generators: plugins },
    },
    { name: "list", description: "Print the registry", icon: "📋" },
    {
      name: "install-test",
      description: "Install from a throwaway copy of the marketplace",
      icon: "🧪",
      args: { name: "plugin", isOptional: true, generators: plugins },
    },
  ],
  args: { name: "plugin", isOptional: true, isVariadic: true, generators: plugins },
};
