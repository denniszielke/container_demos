# Setup environment

## Windows

You can install Azure CLI 2.0 with the MSI and use it in the Windows command-line, or you can install the CLI with apt-get on Bash on Ubuntu on Windows.

### MSI for the Windows command-line 

To install the CLI on Windows and use it in the Windows command-line, download and run the [msi](https://aka.ms/InstallAzureCliWindows).

> [!NOTE]
> When you install with the msi, [`az component`](/cli/azure/component) isn't supported.
> To update to the latest CLI, run the [msi](https://aka.ms/InstallAzureCliWindows) again.
> 
> To uninstall the CLI, run the [msi](https://aka.ms/InstallAzureCliWindows) again and choose uninstall.

### apt-get for Bash on Ubuntu on Windows

1. If you don't have Bash on Windows, [install it](https://msdn.microsoft.com/commandline/wsl/install_guide).

2. Open the Bash shell.

3. Modify your sources list.

```bash
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
```

4. Run the following sudo commands:

```bash
sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893
sudo apt-get install apt-transport-https
sudo apt-get update && sudo apt-get install azure-cli
```

5. Run the CLI from the command prompt with the `az` command.

> [!NOTE]
> When you install with apt-get, [`az component`](/cli/azure/component) isn't supported.
> To update the CLI, run `sudo apt-get update && sudo apt-get install azure-cli` again.
> 
> To uninstall, run `sudo apt-get remove azure-cli`.

6. Create private keypair
`
ssh-keygen -t rsa -b 4096
`

### install and update azure cli on mac

```
brew update && brew install azure-cli

brew upgrade azure-cli

wget https://raw.githubusercontent.com/Homebrew/homebrew-core/7607de411f8ac0ad926ff2caadf8a9abf713cec8/Formula/azure-cli.rb
brew reinsall azure-cli.rb
```

### arm client for mac
https://github.com/yangl900/armclient-go#how-to-use-it

```
curl -sL https://github.com/yangl900/armclient-go/releases/download/v0.2.3/armclient-go_macOS_64-bit.tar.gz | tar xz

```

### install and configure kubectl
https://kubernetes.io/docs/tasks/tools/install-kubectl/

```
az aks install-cli 
brew install kubernetes-cli
brew upgrade kubernetes-cli
```

Install autocompletion
```
kubectl completion -h
```

### install and configure helm
https://get.helm.sh

```
brew install kubernetes-helm
brew upgrade kubernetes-helm
```

### install the preview cli
```
az extension add --name aks-preview
az extension update --name aks-preview
```

remove existing installation of preview cli
```
az extension remove --name aks-preview
```

### install 
```

https://github.com/ohmyzsh/ohmyzsh
https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/kube-ps1

#https://github.com/robbyrussell/oh-my-zsh/tree/master/plugins/kube-ps1
#https://github.com/jonmosco/kube-ps1
PROMPT=$PROMPT'$(kube_ps1) ' 
source "/usr/local/opt/kube-ps1/share/kube-ps1.sh"


#https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/usr/local/share/zsh-syntax-highlighting/highlighters

#ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#999999,bg=cyan,bold,underline"

#https://github.com/zsh-users/zsh-autosuggestions

#bindkey '^ ' forward-word
bindkey '^ ' end-of-line

#https://blog.nillsf.com/index.php/2020/02/17/setting-up-wsl2-windows-terminal-and-oh-my-zsh/
```