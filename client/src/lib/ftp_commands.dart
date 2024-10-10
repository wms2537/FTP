class FtpCommands {
  static String user(String username) => 'USER $username';
  static String pass(String password) => 'PASS $password';
  static String quit() => 'QUIT';
  static String pwd() => 'PWD';
  static String cwd(String directory) => 'CWD $directory';
  static String list([String? path]) => path != null ? 'LIST $path' : 'LIST';
  static String pasv() => 'PASV';
  static String retr(String filename) => 'RETR $filename';
  static String stor(String filename) => 'STOR $filename';
  static String mkd(String directory) => 'MKD $directory';
  static String rmd(String directory) => 'RMD $directory';
  static String dele(String filename) => 'DELE $filename';
  static String size(String filename) => 'SIZE $filename';
}
