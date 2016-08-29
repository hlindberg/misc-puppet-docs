File Provider
---

~~~
plan puppet::file_provider inherits provider {
  type Uid = Integer[0, $settings['maximum_uid']
  
  function uid2name(Uid $id) {
    etc::getpwuid($id).uid
  }
}

~~~