module PryStackExplorer
  StackCommands = Pry::CommandSet.new do
    command "up", "Go up to the caller's context. Accepts optional numeric parameter for how many frames to move up." do |inc_str|
      inc = inc_str.nil? ? 1 : inc_str.to_i

      if !PryStackExplorer.frame_manager(_pry_)
        output.puts "Nowhere to go!"
      else
        binding_index = PryStackExplorer.frame_manager(_pry_).binding_index
        PryStackExplorer.frame_manager(_pry_).change_frame_to binding_index + inc
      end
    end

    command "down", "Go down to the callee's context. Accepts optional numeric parameter for how many frames to move down." do |inc_str|
      inc = inc_str.nil? ? 1 : inc_str.to_i

      if !PryStackExplorer.frame_manager(_pry_)
        output.puts "Nowhere to go!"
      else
        binding_index = PryStackExplorer.frame_manager(_pry_).binding_index
        if binding_index - inc < 0
          output.puts "Warning: At bottom of stack, cannot go further!"
        else
          PryStackExplorer.frame_manager(_pry_).change_frame_to binding_index - inc
        end
      end
    end

    command "show-stack", "Show all frames" do |*args|
      opts = parse_options!(args) do |opt|
        opt.banner unindent <<-USAGE
            Usage: show-stack [OPTIONS]
            Show all accessible stack frames.
            e.g: show-stack -v
          USAGE

        opt.on :v, :verbose, "Include extra information."
      end

      if !PryStackExplorer.frame_manager(_pry_)
        output.puts "No caller stack available!"
      else
        content = ""
        content << "\n#{text.bold('Showing all accessible frames in stack:')}\n--\n"

        PryStackExplorer.frame_manager(_pry_).each_with_index do |b, i|
          if i == PryStackExplorer.frame_manager(_pry_).binding_index
            content << "=> ##{i} #{frame_info(b, opts[:v])}\n"
          else
            content << "   ##{i} #{frame_info(b, opts[:v])}\n"
          end
        end

        stagger_output content
      end
    end

    command "frame", "Switch to a particular frame. Accepts numeric parameter for the target frame to switch to (use with show-stack). Negative frame numbers allowed." do |frame_num|
      if !PryStackExplorer.frame_manager(_pry_)
        output.puts "nowhere to go!"
      else
        if frame_num
          PryStackExplorer.frame_manager(_pry_).change_frame_to frame_num.to_i
        else
          output.puts "##{PryStackExplorer.frame_manager(_pry_).binding_index} #{frame_info(target)}"
        end
      end
    end

    command "frame-type", "Display current frame type." do
      output.puts _pry_.binding_stack.last.frame_type
    end

    helpers do
      def frame_info(b, verbose = false)
        meth = b.eval('__method__')
        b_self = b.eval('self')
        meth_obj = Pry::Method.new(b_self.method(meth)) if meth

        type = b.frame_type ? "(#{b.frame_type})" : ""
        desc = b.frame_description ? "#{text.bold('Description:')} #{b.frame_description}".ljust(60) :
          "#{text.bold('Description:')} #{PryStackExplorer.frame_manager(_pry_).frame_info_for(b)}".ljust(60)
        sig = meth ? "#{text.bold('Signature:')} #{se_signature_with_owner(meth_obj)}".ljust(40) : "".ljust(32)

        slf_class = "#{text.bold('Self.class:')} #{b_self.class}".ljust(40)
        path = "#{text.bold("@ File:")} #{b.eval('__FILE__')}:#{b.eval('__LINE__')}"

        "#{desc} #{slf_class} #{sig} #{type} #{path if verbose}"
      end

      def se_signature_with_owner(meth_obj)
        args = meth_obj.parameters.inject([]) do |arr, (type, name)|
          name ||= (type == :block ? 'block' : "arg#{arr.size + 1}")
          arr << case type
                 when :req   then name.to_s
                 when :opt   then "#{name}=?"
                 when :rest  then "*#{name}"
                 when :block then "&#{name}"
                 else '?'
                 end
        end

        "#{meth_obj.name_with_owner}(#{args.join(', ')})"
      end
    end

  end
end
