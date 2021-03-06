# Initialize my ruby via rvm

setopt interactivecomments

# install rvm and compile latest ruby
\curl -sSL https://get.rvm.io | bash -s stable --ruby
if [[ -s ~/.rvm/scripts/rvm ]] ; then source ~/.rvm/scripts/rvm ; fi
rvm get head
rvm reload

rvm autolibs homebrew
rvm requirements
