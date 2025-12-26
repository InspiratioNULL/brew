# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "formula"
require "formulary"
require "keg"

module Homebrew
  module Cmd
    class Unlinked < AbstractCommand
      cmd_args do
        description <<~EOS
          List installed formulae that are not linked, excluding keg-only formulae
          (since those are expected to be unlinked anyway).
        EOS
        switch "--why",
               description: "Show why each formula is unlinked (conflict with another formula, " \
                            "external file exists, or manually unlinked)."
        switch "--desc",
               description: "Show formula descriptions."

        named_args :none
      end

      sig { override.void }
      def run
        unlinked_racks = Formula.racks.reject do |rack|
          next true if (HOMEBREW_LINKED_KEGS/rack.basename).directory?

          begin
            Formulary.from_rack(rack).keg_only?
          rescue FormulaUnavailableError, TapFormulaAmbiguityError
            false
          end
        end

        unlinked_racks.map { |rack| rack.basename.to_s }.sort.each do |name|
          output = name

          if args.desc?
            formula = begin
              Formulary.factory(name)
            rescue FormulaUnavailableError
              nil
            end
            output += ": #{formula.desc}" if formula&.desc
          end

          if args.why?
            reason = why_unlinked(name)
            output += args.desc? ? " [#{reason}]" : ": #{reason}"
          end

          puts output
        end
      end

      private

      sig { params(name: String).returns(String) }
      def why_unlinked(name)
        formula = Formulary.factory(name)
      rescue FormulaUnavailableError
        "formula unavailable"
      else
        keg = formula.any_installed_keg
        return "no keg found" unless keg

        # check for actual file conflicts in bin/sbin
        conflict = find_file_conflict(keg)
        return conflict if conflict

        # check for declared conflicts with installed packages
        declared = find_declared_conflict(formula)
        return declared if declared

        "manually unlinked"
      end

      sig { params(keg: Keg).returns(T.nilable(String)) }
      def find_file_conflict(keg)
        %w[bin sbin].each do |dir|
          keg_dir = keg/dir
          next unless keg_dir.directory?

          keg_dir.children.each do |src|
            next if src.basename.to_s == ".DS_Store"

            dst = HOMEBREW_PREFIX/dir/src.basename
            next if !dst.exist? && !dst.symlink?

            return "conflict: external file (#{dst.basename})" unless dst.symlink?

            begin
              owner = Keg.for(dst.resolved_path)
              return "conflict: #{owner.name}" if owner.name != keg.name
            rescue NotAKegError
              return "conflict: external file (#{dst.basename})"
            rescue Errno::ENOENT
              next # broken symlink, not a real conflict
            end
          end
        end
        nil
      end

      sig { params(formula: Formula).returns(T.nilable(String)) }
      def find_declared_conflict(formula)
        formula.conflicts.each do |conflict|
          conflicting_formula = begin
            Formulary.factory(conflict.name)
          rescue FormulaUnavailableError
            next
          end
          next unless conflicting_formula.any_installed_keg
          next unless (HOMEBREW_LINKED_KEGS/conflict.name).directory?

          reason = conflict.reason ? " (#{conflict.reason})" : ""
          return "declared conflict: #{conflict.name}#{reason}"
        end
        nil
      end
    end
  end
end
