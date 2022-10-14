# frozen_string_literal: true

#  export.rb
#
#  Copyright 2017 Jan Brouwer <jan@brewsky.nl>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#
#

require_relative File.join('lib', 'lib_ifc', 'IfcModel')

module BimTools
  module IfcManager
    require 'net/http'
    require 'uri'
    require File.join(PLUGIN_PATH, 'update_ifc_fields')
    require File.join(PLUGIN_PATH_LIB, 'progressbar')

    def export(file_path)
      su_model = Sketchup.active_model

      # close previous export summary if still open
      @summary_dialog.close if @summary_dialog

      # reset export messages
      IfcManager.export_messages = []

      # create new progressbar
      pb = ProgressBar.new(4, "Exporting to #{ifc_version = Settings.ifc_version}...")

      # start timer
      timer = Time.now

      # get export options
      options = Settings.export

      # update all IFC name fields with the component definition name
      # (?) is this necessary, or should this already be 100% correct at the time of export?
      su_model.start_operation('Update IFC data', true)
      IfcManager.update_ifc_fields(su_model)
      su_model.commit_operation

      pb.update(1)

      # create new IfcModel
      ifc_model = IfcModel.new(su_model, options)

      pb.update(2)

      # get total time
      puts "finished creating #{ifc_version = Settings.ifc_version} entities: #{Time.now - timer}"

      # export model to IFC step file
      ifc_model.export(file_path)

      pb.update(3)

      # get total time
      time = Time.now - timer
      puts "finished export: #{time}"

      pb.update(4)

      show_summary(ifc_model.export_summary, file_path, time)

      # write log
      begin
        # run in seperate thread to prevent waiting
        Thread.new do
          uri = URI.parse('http://www.bim4sketchup.org/log.php')
          http = Net::HTTP.new(uri.host, uri.port)
          request = Net::HTTP::Post.new(uri.request_uri)
          request.set_form_data({ 'version' => VERSION, 'extension' => 'Sketchup IFC Manager' })
          http.request(request)
        end
      rescue StandardError
        puts 'failed writing log.'
      end
    end

    def add_export_message(message)
      IfcManager.export_messages << message
    end

    def show_summary(hash, file_path, time)
      css = File.join(PLUGIN_PATH_CSS, 'sketchup.css')
      html = +"<html><head><link rel='stylesheet' type='text/css' href='#{css}'></head><body><textarea readonly>#{ifc_version = Settings.ifc_version} Entities exported:\n\n"
      hash.each_pair do |key, value|
        html << "#{value} #{key}\n"
      end
      html << "\n To file '#{file_path}'\n"
      html << "\n Taking a total number of #{time} seconds\n"
      unless IfcManager.export_messages.empty?
        messages = IfcManager.export_messages.uniq.sort.join("\n- ")
        html << "\nMessages:\n- #{messages}\n"
      end
      html << '</textarea></body></html>'
      @summary_dialog = UI::HtmlDialog.new(
        {
          dialog_title: 'Export results',
          scrollable: false,
          resizable: true,
          width: 320,
          height: 520,
          left: 200,
          top: 200,
          style: UI::HtmlDialog::STYLE_UTILITY
        }
      )
      @summary_dialog.set_html(html)
      @summary_dialog.show
    end
  end
end
