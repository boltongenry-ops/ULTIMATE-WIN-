package main

import (
	"bytes"
	"embed"
	"encoding/base64"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"unsafe"
)

//go:embed app/*.ps1 assets/drivers.json
var files embed.FS

func main() {
	if len(os.Args) == 2 && os.Args[1] == "--driver-catalog" {
		data, err := files.ReadFile("assets/drivers.json")
		if err != nil {
			os.Exit(1)
		}
		if _, err = os.Stdout.Write(data); err != nil {
			os.Exit(1)
		}
		return
	}
	var script bytes.Buffer
	script.WriteString("$ErrorActionPreference='Stop'\n")
	for _, name := range []string{"workers", "ui"} {
		data, err := files.ReadFile("app/" + name + ".ps1")
		if err != nil {
			panic(err)
		}
		if name == "workers" {
			fmt.Fprintf(&script, "$workerSource=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('%s'))\n", base64.StdEncoding.EncodeToString(data))
		} else {
			script.Write(data)
		}
	}
	shell := filepath.Join(os.Getenv("SystemRoot"), "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
	cmd := exec.Command(shell, "-NoLogo", "-NoProfile", "-NonInteractive", "-STA", "-Command", "[Console]::InputEncoding=[Text.UTF8Encoding]::new($false); . ([ScriptBlock]::Create([Console]::In.ReadToEnd()))")
	launcher, err := os.Executable()
	if err == nil {
		cmd.Env = append(os.Environ(), "ULTIMATEWIN_EXE="+launcher)
	}
	cmd.Stdin = &script
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	if out, err := cmd.CombinedOutput(); err != nil {
		msg, _ := syscall.UTF16PtrFromString(strings.ReplaceAll(fmt.Sprintf("Ошибка запуска: %v\n%s", err, out), "\x00", ""))
		title, _ := syscall.UTF16PtrFromString("Ultimate Win")
		syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(msg)), uintptr(unsafe.Pointer(title)), 16)
	}
}
