# DelayScope

Evaluate various system components to measure their responsiveness in terms of latency. It runs a series of tests on your system and gives you an in-depth look at how each key resource is performing. It generates a final score that summarizes the overall system responsiveness, with detailed reports on each component's performance.

## Key components tested:

- **CPU Responsiveness: Measures how quickly the processor responds to complex operations.**

- **Disk Responsiveness: Measures the disk’s read and write performance.**

- **Memory Responsiveness: Assesses the memory performance by allocating and processing test data.**

- **Network Responsiveness: Evaluates network latency by pinging a target (Google DNS).**

# How to Run

### Run the command below in PowerShell:

```ps1
iwr "https://raw.githubusercontent.com/ltx0101/DelayScope/main/DelayScope.ps1" -OutFile "DelayScope.ps1"; .\DelayScope.ps1
```

---

<details>
<summary> Requirements </summary>

- Windows 10/11
- PowerShell
</details>

<details>
<summary>Error "Running Scripts is Disabled on this System"</summary>

### Run this command in PowerShell:

```ps1
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
```
</details>
<div align="center">

---

<div align="center">
   
[![PayPal Donate](https://img.shields.io/badge/PayPal_Donate-s?style=for-the-badge&logo=paypal&logoColor=black)](https://paypal.me/AggelosMeta)

</div>

<div align="center">
  
Made with ❤️ and PowerShell  

</div>
