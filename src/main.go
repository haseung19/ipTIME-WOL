//go:build windows

// A small, native Windows launcher for the tested PowerShell WOL GUI.
// It packages the complete application into one distributable EXE.
// The embedded script is executed as a temporary file and removed on exit.
package main

import (
	"bytes"
	_ "embed"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"unsafe"
)

//go:embed ipTIME-WOL.ps1
var embeddedScript []byte

const appTitle = "ipTIME WOL"

var (
	user32      = syscall.NewLazyDLL("user32.dll")
	messageBoxW = user32.NewProc("MessageBoxW")
)

func messageBox(title, message string, isError bool) {
	titleUTF16, err1 := syscall.UTF16PtrFromString(title)
	textUTF16, err2 := syscall.UTF16PtrFromString(message)
	if err1 != nil || err2 != nil {
		return
	}
	kind := uintptr(0x40) // MB_ICONINFORMATION
	if isError {
		kind = 0x10 // MB_ICONERROR
	}
	messageBoxW.Call(0, uintptr(unsafe.Pointer(textUTF16)), uintptr(unsafe.Pointer(titleUTF16)), kind)
}

func run() error {
	wake := false
	if len(os.Args) > 2 {
		return errors.New("알 수 없는 인수가 전달되었습니다.")
	}
	if len(os.Args) == 2 {
		switch strings.ToLower(os.Args[1]) {
		case "--wake", "-wake":
			wake = true
		default:
			return fmt.Errorf("지원하지 않는 실행 옵션: %s", os.Args[1])
		}
	}

	exePath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("실행 파일 위치를 확인할 수 없습니다: %w", err)
	}
	exePath, err = filepath.Abs(exePath)
	if err != nil {
		return err
	}

	// CreateTemp uses a per-user temporary directory with a random filename.
	// Avoid using cmd.exe or encoding the whole script in a command line.
	scriptFile, err := os.CreateTemp("", "iptime-wol-*.ps1")
	if err != nil {
		return fmt.Errorf("임시 실행 파일 생성 실패: %w", err)
	}
	scriptPath := scriptFile.Name()
	defer os.Remove(scriptPath)

	if _, err := scriptFile.Write(embeddedScript); err != nil {
		scriptFile.Close()
		return fmt.Errorf("임시 실행 파일 기록 실패: %w", err)
	}
	if err := scriptFile.Close(); err != nil {
		return fmt.Errorf("임시 실행 파일 닫기 실패: %w", err)
	}

	windir := os.Getenv("WINDIR")
	if windir == "" {
		windir = os.Getenv("SystemRoot")
	}
	if windir == "" {
		return errors.New("Windows 시스템 폴더를 찾을 수 없습니다.")
	}
	powershell := filepath.Join(windir, "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
	if _, err := os.Stat(powershell); err != nil {
		return fmt.Errorf("Windows PowerShell 5.1을 찾을 수 없습니다: %w", err)
	}

	args := []string{"-NoProfile", "-ExecutionPolicy", "Bypass", "-STA", "-WindowStyle", "Hidden", "-File", scriptPath}
	if wake {
		args = append(args, "-WakeSaved")
	}
	cmd := exec.Command(powershell, args...)
	cmd.Env = append(os.Environ(), "IPTIME_WOL_EXE="+exePath)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}

	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output
	if err := cmd.Run(); err != nil {
		details := strings.TrimSpace(output.String())
		if len(details) > 1400 {
			details = details[:1400] + "..."
		}
		if details != "" {
			return fmt.Errorf("PowerShell 실행 오류: %w\n\n%s", err, details)
		}
		return fmt.Errorf("PowerShell 실행 오류: %w", err)
	}
	return nil
}

func main() {
	if err := run(); err != nil {
		messageBox(appTitle+" 실행 오류", err.Error(), true)
		os.Exit(1)
	}
}
