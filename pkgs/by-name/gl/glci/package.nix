{
  lib,
  buildGoModule,
  fetchFromGitLab,
  gitMinimal,
  makeWrapper,
  nix-update-script,
  runCommand,
  runtimeShell,
  writableTmpDirAsHomeHook,
}:

buildGoModule (finalAttrs: {
  pname = "glci";
  version = "0.7.0";

  __structuredAttrs = true;

  src = fetchFromGitLab {
    group = "gitlab-org/ci-cd";
    owner = "runner-tools";
    repo = "glci";
    rev = "917cd8ecaf1af7377d48ee83cdd1b2c35c6c53c2";
    hash = "sha256-S6MvJIAQmRqrME+sl/2MUiQ2FsStbcn6lclxRY8s+X4=";
  };

  vendorHash = "sha256-XOpUoZGQy6eZxHIfi52Bfpwg5GKj0DUSPDG+vx02Hs4=";

  env.CGO_ENABLED = 0;

  subPackages = [ "cmd/glci" ];

  ldflags = [
    "-X gitlab.com/gitlab-org/ci-cd/runner-tools/glci/pkg/version.Commit=${finalAttrs.src.rev}"
  ];

  nativeBuildInputs = [ makeWrapper ];

  nativeCheckInputs = [
    gitMinimal
    writableTmpDirAsHomeHook
  ];

  postPatch = ''
    substituteInPlace pkg/daemon/endpoint_test.go \
      --replace-fail "#!/bin/sh" "#!${runtimeShell}" \
      --replace-fail "/usr/bin/env" "env" \
      --replace-fail "/bin/cat" "cat"

    substituteInPlace pkg/config/testdata/gitlab/raw/.gitlab-ci.yml \
      --replace-fail \
        "  - remote: 'https://gitlab.com/gitlab-org/frontend/untamper-my-lockfile/-/raw/main/templates/merge_request_pipelines.yml'" \
        "  - local: .gitlab/ci/untamper-my-lockfile.yml"

    cat > pkg/config/testdata/gitlab/raw/.gitlab/ci/untamper-my-lockfile.yml <<'EOF'
    untamper-my-lockfile:
      image: registry.gitlab.com/gitlab-org/frontend/untamper-my-lockfile:main
      stage: test
      needs: []
      before_script: []
      after_script: []
      cache: {}
      retry: 1
      script:
        - untamper-my-lockfile --lockfile yarn.lock
      rules:
        - if: $CI_MERGE_REQUEST_SOURCE_BRANCH_NAME == "add-untamper-my-lockfile"
        - if: $CI_MERGE_REQUEST_IID
          changes:
            - yarn.lock
        - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
          changes:
            - yarn.lock
    EOF
  '';

  preCheck = ''
    git init --quiet --initial-branch=main
    git config user.email glci-tests@example.invalid
    git config user.name "glci tests"
    git add .
    git commit --quiet --message "Test fixture"
    git remote add origin https://gitlab.com/gitlab-org/ci-cd/runner-tools/glci.git
  '';

  checkPhase = ''
    runHook preCheck
    # We do not set trimpath for tests, in case they reference test assets
    export GOFLAGS=''${GOFLAGS//-trimpath/}

    go test ./...

    runHook postCheck
  '';

  postInstall = ''
    wrapProgram $out/bin/glci --prefix PATH : ${lib.makeBinPath [ gitMinimal ]}
  '';

  passthru.tests.version = runCommand "glci-version-test" { } ''
    ${finalAttrs.finalPackage}/bin/glci version 2>&1 \
      | grep -F ${finalAttrs.src.rev}
    touch $out
  '';

  passthru.updateScript = nix-update-script {  };

  meta = {
    description = "Run GitLab CI/CD pipelines locally";
    homepage = "https://gitlab.com/gitlab-org/ci-cd/runner-tools/glci";
    changelog = "https://glci-e20136.gitlab.io/changelog/v${finalAttrs.version}/";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ lildojd ];
    mainProgram = "glci";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
})
