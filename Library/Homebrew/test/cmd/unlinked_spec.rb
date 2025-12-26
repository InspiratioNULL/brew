# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "cmd/unlinked"

RSpec.describe Homebrew::Cmd::Unlinked do
  it_behaves_like "parseable arguments"

  it "lists unlinked formulae", :integration_test do
    install_test_formula "testball"
    Formula["testball"].any_installed_keg.unlink

    expect { brew "unlinked" }
      .to output("testball\n").to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end
end
