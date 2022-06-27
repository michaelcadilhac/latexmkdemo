function verbatim_gt(filename)
   -- A table containing a "reader" function for reading a line.
   -- This cannot return two lines at a time; if needed, one can buffer.
   local ret = {}
   ret.file = io.open(filename)
   ret.reformat = false
   ret.reader =
      function(t)
         local line = t.file:read()
         if line == nil then return line end
         if (string.match (line, '^>')) then
            line = line:gsub ('^>[ \t]*', '')
            if not ret.reformat then
               ret.reformat = true
               return '\\begin{verbatim}' .. line
            else
               return line
            end
         else
            if ret.reformat then
               ret.reformat = false
               return '\\end{verbatim}' .. line
            else
               return line
            end
         end
      end
   return ret
end

-- Only one such callback can be installed.
luatexbase.add_to_callback('open_read_file', verbatim_gt, 'verbatim_gt')
