// if you use jsx, you have to import React
import React                          from 'react';
import { Router, Route, IndexRoute }  from 'react-router';

import appHistory                     from './history';
import Index                          from './components/layout/index';
import Home                          from './components/home';
import NotFound                       from './components/common/not_found';
import Instances                      from './components/admin/instances/_instances';

export default (
  <Router history={appHistory}>
    <Route path="/" component={Index}>
      <IndexRoute component={Home} />
    </Route>
    <Route path="*" component={NotFound} />
  </Router>
);
