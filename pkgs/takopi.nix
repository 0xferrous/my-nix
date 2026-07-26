{
  lib,
  python314Packages,
  fetchFromGitHub,
  git,
  makeWrapper,
}:

let
  py = python314Packages;

  sulguk = py.buildPythonPackage rec {
    pname = "sulguk";
    version = "0.12.0";
    pyproject = true;

    src = py.fetchPypi {
      inherit pname version;
      hash = "sha256-gms8vBrD6d8hXcTYpMVkVp4MF3fk8fRZ5oKXmNrUqTw=";
    };

    build-system = [ py.setuptools ];
    dependencies = with py; [
      html5lib
      lxml
    ];

    pythonImportsCheck = [ "sulguk" ];

    meta = {
      description = "Converter from HTML to Telegram entities";
      homepage = "https://github.com/tishka17/sulguk";
      license = lib.licenses.asl20;
    };
  };
in
py.buildPythonApplication rec {
  pname = "takopi";
  version = "0.23.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "banteg";
    repo = "takopi";
    rev = "v${version}";
    hash = "sha256-dJx15XcAzikFdzV/nS+DThSFJDWpOMitQA2JMW9t1kA=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'uv_build>=0.9.18,<0.10.0' 'uv_build>=0.9.18,<0.12.0'
  '';

  build-system = [ py.uv-build ];

  dependencies = with py; [
    anyio
    httpx
    markdown-it-py
    msgspec
    openai
    pydantic
    pydantic-settings
    questionary
    rich
    structlog
    sulguk
    tomli-w
    typer
    watchfiles
  ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/takopi \
      --prefix PATH : ${lib.makeBinPath [ git ]}
  '';

  pythonImportsCheck = [ "takopi" ];

  meta = {
    description = "Telegram bridge for Codex, Claude Code, and other agent CLIs";
    homepage = "https://takopi.dev/";
    changelog = "https://github.com/banteg/takopi/blob/v${version}/changelog.md";
    license = lib.licenses.mit;
    mainProgram = "takopi";
    platforms = lib.platforms.unix;
  };
}
