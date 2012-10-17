#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# Copyright © 2012 Diego Elio Pettenò <flameeyes@flameeyes.eu>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND INTERNET SOFTWARE CONSORTIUM DISCLAIMS
# ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL INTERNET SOFTWARE
# CONSORTIUM BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
# DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
# PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS
# ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
# SOFTWARE.

require 'set'

seen_ids = Set.new

# open all the rule files
Dir["*/*.conf"].each do |rulefile|
  # read the content
  content = File.read(rulefile)
  # join the lines where continuation is used
  content.gsub!(/\\\n/, '')

  lineno = 0
  this_chained = next_chained = false

  # for each line in the rule file
  content.each_line do |line|
    lineno += 1

    # remove comments
    line.gsub!(/(^|[^'"]|'[^']*'|"[^"]*")#.*/) { $1 }
    # and skip if it's an empty line (this also skip comment-only lines)
    next if line =~ /^\s+$/

    this_chained = next_chained
    next_chained = false

    # split the directive in its components, considering quoted strings
    directive = line.scan(/([^'"\s]+|'[^']*'|"[^"]*")(?:\s+|$)/).flatten
    directive.map! do |piece|
      # then make sure to split the quoting out of the quoted strings
      (piece[0] == '"' || piece[0] == "'") ? piece[1..-2] : piece
    end

    # skip if it's not a SecRule
    next if directive[0] != "SecRule"

    # get the rule and split in its components
    rule = (directive[3] || "").split(',')

    if rule.include?("chain")
      next_chained = true
    end

    ids = rule.find_all { |piece| piece =~ /^id:/ }
    if ids.size > 1
      $stderr.puts "#{rulefile}:#{lineno} rule with multiple ids"
      next
    elsif ids.size == 0
      id = nil
    else
      id = ids[0].sub(/^id:/, '').to_i
    end

    if this_chained
      $stderr.puts "#{rulefile}:#{lineno} chained rule with id" unless id.nil?
      next
    elsif id.nil?
      $stderr.puts "#{rulefile}:#{lineno} rule missing id (#{rule.join(',')})"
      next
    elsif id < 430000 || id > 439999
      $stderr.puts "#{rulefile}:#{lineno} rule with id outside of reserved range"
    elsif seen_ids.include?(id)
      $stderr.puts "#{rulefile}:#{lineno} rule with duplicated id"
    end

    seen_ids << id
  end
end