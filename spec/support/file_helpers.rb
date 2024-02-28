# frozen_string_literal: true

module FileHelpers
  def create_file(path, contents)
    folder = File.dirname(path)
    FileUtils.mkdir_p(folder)
    File.write(path, contents)
  end

  def create_empty_file(path)
    create_file(path, nil)
  end

  def read_file_timestamps(path)
    {
      created_at: File.ctime(path),
      modified_at: File.mtime(path)
    }
  end

  def list_folder_entries(folder)
    Dir["#{folder}/*"]
  end
end
