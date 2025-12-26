# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "formula"
require "formulary"

module Homebrew
  module Cmd
    class Unlinked < AbstractCommand
      cmd_args do
        description <<~EOS
          List installed formulae that are not linked, excluding keg-only formulae
          (since those are expected to be unlinked anyway).
        EOS

        named_args :none
      end

      sig { override.void }
      def run
        unlinked = Formula.racks.reject do |rack|
          next true if (HOMEBREW_LINKED_KEGS/rack.basename).directory?

          begin
            Formulary.from_rack(rack).keg_only?
          rescue FormulaUnavailableError, TapFormulaAmbiguityError
            false
          end
        end

        unlinked.map { |rack| rack.basename.to_s }.sort.each { |name| puts name }
      end
    end
  end
end
