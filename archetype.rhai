let context = #{};

context += prompt("Github Organization:", "organization-name", #{
  placeholder: "acme-inc",
  help: "The organization or username where this project will be published",
});

context += prompt("Project Title:", "project-title", #{
  placeholder: "Customer",
  help: "The title of the Modern.js application",
});

context += prompt("Project Prefix:", "project-prefix", #{
  defaults_with: render("{{ project-title | kebab_case }}", context),
  help: "The project name; suffix '-app' will be appended automatically",
  cases: [
    CasedIdentityCasedValue(PROGRAMMING_CASES),
  ], 
});

context += prompt("Host Repository Name (optional):", "host-repository-name", #{
  defaults_with: nu,
  optional: true,
  help: "The repository name of the host to commit the output to (if hosting MFEs in a consolidated host)",
})

if context["host-repository-name"] != nu {
  context += prompt("Host Repository Branch (optional):", "host-repository-branch", #{
    defaults_with: "main",
    help: "The branch name in the host to commit the output to (if hosting MFEs in a consolidated host)",
  })
}

context += prompt("Port:", "port", #{
  defaults_with: "3000",
  help: "Port for the MFE app",
});

context += set("project-suffix", "app");

context += set("project-name", render("{{ project-prefix }}-{{ project-suffix }}", context), #{
  cases: [
    CasedIdentityCasedValue(PROGRAMMING_CASES),
  ],
});

render(Directory("contents/base"), context);

//
// Publishing
//
if switch_enabled("zip") {
  zip(context["project-name"], render("{{ project-name }}.zip", context));
}
if switch_enabled("tarball") {
  tar_gz(context["project-name"], render("{{ project-name }}.tar.gz", context));
}

if switch_enabled("git-init") || switch_enabled("git-publish") {
  git_init(context["project-name"], "main");
  git_add_all(context["project-name"]);
  git_commit(context["project-name"], "initial commit");
  git_remote_add(context["project-name"], "origin", render("https://github.com/{{ organization-name }}/{{ project-name }}.git", context));

  if switch_enabled("git-publish") {
    gh_repo_create(render("{{ organization-name }}/{{ project-name }}", context), Private);
    git_push(context["project-name"], "origin", "main");
  }
} else {
  display();

  log(Info, "Copy and paste the following commands to publish your project:");

  display();

  display(render("cd {{ project-name }}", context));
  display("git init -b main");
  display(render("gh repo create {{ organization-name }}/{{ project-name }} --private --source=. --remote=origin", context));
  display("git add .");
  display("git commit -m 'initial commit'");
  display("git push -u origin HEAD");
}

